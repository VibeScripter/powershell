function Copy-AzureRMLocalToBlob
{
	<#
	.SYNOPSIS
		This script aims to simplify and help you upload files to Azure blob storage :) 

	.PARAMETER Files
		just use any localpath pointing to your azure blobs

	.PARAMETER CtnrNameSpace
		This will define the name(s) of the Azure storage account the file(s) will be placed in.

	.PARAMETER NewCtnrName
		Name of the files - make sure it is the same as you want it to be in there as is in your local storage :)

	.PARAMETER BlobType
		This parameter points the blobtype definition / file type to where you wish for your files to be upon upload

	.PARAMETER ResourceGroupName
		This parameter defines the specific name of the resource group it's in

	.PARAMETER StorageAcc
		This parameter defines the name of the storage account the file will be contained in
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[Alias('FullName')]
		[string]$Files,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$CtnrNameSpaceName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ResourceGroupName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$StorageAcc,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$NewCtnrName,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Page', 'Block')]
		[string]$BlobType = 'Page'
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$saParams = @{
				'ResourceGroupName' = $ResourceGroupName
				'Name' = $StorageAcc
			}

			$storageCtnrNameSpace = Get-AzureRmStorageAccount @saParams | Get-AzureStorageCtnrNameSpace -CtnrNameSpace $CtnrNameSpaceName

			if (-not $PSBoundParameters.ContainsKey('NewCtnrName'))
			{
				$NewCtnrName = $Files | Split-Path -Leaf
			}

			## Use Add-AzureRmVhd if the file is a VHD. Set-AzureStorageBlobContent is known to corrupt the large VHD when uploading
			if ($Files.EndsWith('.vhd'))
			{
				$destination = ('{0}{1}/{2}' -f $storageCtnrNameSpace.Context.BlobEndPoint, $CtnrNameSpaceName, $NewCtnrName)
				$vhdParams = @{
					'ResourceGroupName' = $ResourceGroupName
					'Destination' = $destination
					'LocalFiles' = $Files
				}
				Write-Verbose -Message "Uploading [$($vhdParams.LocalFiles)] to [$($vhdParams.Destination)] in resource group [$($vhdParams.ResourceGroupName)]..."
				Add-AzureRmVhd @vhdParams
			}
			else
			{
				$bcParams = @{
					'File' = $Files
					'BlobType' = $BlobType
					'Blob' = $NewCtnrName
				}
				$storageCtnrNameSpace | Set-AzureStorageBlobContent @bcParams
			}
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}