function GetFileSizeOnDisk {
[OutputType([int])]
param(
    [parameter(ParameterSetName='FilePath', Mandatory=$true, Position=0)]
        [string]$FilePath
)
$source = @"
using System;
using System.Runtime.InteropServices;
using System.ComponentModel;
using System.IO;
namespace Win32
{ 
    public class Disk {
        [DllImport("kernel32.dll")]
        static extern uint GetCompressedFileSizeW([In, MarshalAs(UnmanagedType.LPWStr)] string lpFileName,
        [Out, MarshalAs(UnmanagedType.U4)] out uint lpFileSizeHigh);	    
        public static ulong GetSizeOnDisk(string filename)
        {
            uint HighOrderSize;
            uint LowOrderSize;
            ulong size;

            FileInfo file = new FileInfo(filename);
            LowOrderSize = GetCompressedFileSizeW(file.FullName, out HighOrderSize);

            if (HighOrderSize == 0 && LowOrderSize == 0xffffffff)
            {
	            throw new Win32Exception(Marshal.GetLastWin32Error());
            }
            else { 
	            size = ((ulong)HighOrderSize << 32) + LowOrderSize;
	            return size;
            }
        }
    }
}
"@
Add-Type -TypeDefinition $source
$size=[Win32.Disk]::GetSizeOnDisk((Get-Item "$($FilePath)").FullName)
return $size 
}