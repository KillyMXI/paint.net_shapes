<#
.SYNOPSIS
Converts generic XAML files to Paint.NET shape XAML files.

.DESCRIPTION
Parameter aliases:
    -i  -in      <path>     Input file or folder
    -o  -out     <path>     Output folder
    -p  -pretty             If present, output files will be human-readable

Display name of each shape will be set according to filename.

If you set output to the same folder where input file located,
then suffix "_converted" will be added to output file name (not display name).

.PARAMETER inputPath
Input file or folder to be converted.

.PARAMETER outDir
Folder where converted files should be placed.
Folder will be created in case it isn't exist already.

.PARAMETER prettyPrint
If present, output XAML files will be formatted for readability and further editing.
Otherwise there will be no new lines and indentation.

.EXAMPLE
./_convert.ps1 .\shape_sources
Convert all files in .\shape_sources folder (non-recursive).
Default output folder is .\output

.EXAMPLE
./_convert.ps1 -in .\shape_sources -pretty
Convert all files in .\shape_sources folder (non-recursive).
Default output folder is .\output
Output files formatted for readability and further editing.

.EXAMPLE
./_convert.ps1 .\some_folder\example.xaml
Convert single file.
Converted file will be saved into .\output folder by default.

.EXAMPLE
./_convert.ps1 .\shape_sources .\output
Convert all files in .\shape_sources folder (non-recursive)
and put resulting files into .\output folder.

.EXAMPLE
./_convert.ps1 -i .\shape_sources -o .\output -p
Parameters can be unnamed (ordered) or named with full names
or one letter aliases like in this example.

.NOTES
Put some notes here.

.LINK
http://mxii.eu.org/project/paintdotnetstuff           - This script and other my stuff for Paint.NET

.LINK
http://forums.getpaint.net/index.php?/topic/32101-h   - How to make custom shapes for Paint.NET

#>

Param (
    [Parameter(Mandatory, HelpMessage="Input file or folder to be converted.")]
    [ValidateScript({Test-Path $_})] 
    [Alias("i","in")][string]$inputPath,
    
    [Alias("o","out")][string]$outDir = ".\output",
    
    [Alias("p","pretty")][switch]$prettyPrint
)

#$DebugPreference = "Continue"
Set-StrictMode -Version Latest

# Constants
$extendedFileNameSuffix = "_converted"

function Convert-Shapes {
    if(-Not (Test-Path $outDir)) { # make output folder if needed
        New-Item -ItemType directory -Path $outDir | Out-Null
    }
    $inputItem = Get-Item -Path $inputPath
    $outputFolderItem = Get-Item -Path $outDir
    if (Test-Path $inputPath -PathType Container) # folder
    {
        Convert-Folder $inputItem $outputFolderItem
    }
    else # single file
    {
        Convert-SingleFile $inputItem $outputFolderItem
    }
    Write-Output "    Finished."
}

function Convert-Folder($inputFolder, $outputFolder) {
    $fileList = Get-ChildItem "$($inputFolder.FullName)\" -Filter *.xaml -File
    Write-Output "    $($fileList.Count) files to convert."
    $fileList | %{ Convert-SingleFile $_ $outputFolder }
}

function Convert-SingleFile($inputFile, $outputFolder) {
    Write-Debug "$($inputFile.FullName)"
    $conversionResult = Convert-Item $inputFile
    $xml = $conversionResult["xml"]
    $attrBased = $conversionResult["attributeBased"]
    $outputFilePath = Make-OutputPath $inputFile $outputFolder $false
    if($inputFile.FullName -eq $outputFilePath) # avoid overwriting of input file
    {
        $outputFilePath = Make-OutputPath $inputFile $outputFolder $true
    }
    Save-ShapeXml $xml $outputFilePath $prettyPrint.IsPresent $attrBased
}

function Make-OutputPath($item, $outputFolder, $isExtendedName) {
    Return "$outputFolder\$($item.BaseName)$(if($isExtendedName){$extendedFileNameSuffix}).xaml"
}

function Convert-Item($fileItem) {
    $shapeName = $fileItem.BaseName
    $xdoc = [xml] (Get-Content $fileItem.FullName)
    $ns = New-Object System.Xml.XmlNamespaceManager($xdoc.NameTable)
    $ns.AddNamespace("ns", $xdoc.DocumentElement.NamespaceURI)
    $xPathNode = $xdoc.SelectSingleNode("//ns:Path", $ns)
    if($xPathNode.HasAttribute("Data"))
    {
        Return @{
            "xml" = Make-AttributeShape $xPathNode.Data $shapeName;
            "attributeBased" = $true
            }
    }
    else
    {
        Return @{
            "xml" = Make-NodeShape $xPathNode.'Path.Data'.InnerXml $shapeName;
            "attributeBased" = $false
            }
    }
}

function Make-AttributeShape([string]$stringData, [string]$shapeName) {
    $doc = Get-ShapeTemplate
    $doc.SimpleGeometryShape.SetAttribute("DisplayName", $shapeName)
    $doc.SimpleGeometryShape.SetAttribute("Geometry", $stringData)
    Return $doc
}

function Make-NodeShape($xml, [string]$shapeName) {
    $doc = Get-ShapeTemplate
    $doc.SimpleGeometryShape.SetAttribute("DisplayName", $shapeName)
    $doc.SimpleGeometryShape.InnerXml = $xml
    Return $doc
}

function Get-ShapeTemplate {
    Return [xml]"<ps:SimpleGeometryShape xmlns=""clr-namespace:PaintDotNet.UI.Media;assembly=PaintDotNet.Framework""
                                         xmlns:ps=""clr-namespace:PaintDotNet.Shapes;assembly=PaintDotNet.Framework"" />"
}

function Save-ShapeXml($xmldoc, $outputPath, $isPrettyPrint, $isAttrNewLine) {
    # Removing namespace which was added when xml fragmant was grafted from one file to another.
    $outstr = $xmldoc.OuterXml.Replace(" xmlns=`"http://schemas.microsoft.com/winfx/2006/xaml/presentation`"", "")
    if($isPrettyPrint)
    {
        $outstr = XmlPrettyPrint $outstr $isAttrNewLine
    }
    # Using XmlWriter in XmlPrettyPrint function messes the encoding.
    # Making utf8 without BOM explicitly here.
    $utf8noBOM = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($outputPath, $outstr, $utf8noBOM)
}

function XmlPrettyPrint([string]$xmlstr, $isAttrNewLine) {
    $sw = New-Object System.IO.StringWriter
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.CloseOutput = $true
    $settings.Indent = $true
    $settings.NewLineOnAttributes = $isAttrNewLine
    $settings.OmitXmlDeclaration = $true
    $writer = [System.Xml.XmlWriter]::Create($sw, $settings)
    
    $xmldoc = New-Object system.xml.xmlDataDocument 
    $xmldoc.LoadXml($xmlstr) 
    $xmldoc.WriteContentTo($writer)
    $writer.Flush()
    
    Return $sw.ToString()
}

Convert-Shapes
