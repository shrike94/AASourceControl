Configuration InstallFortuneCow
{
    Import-DSCResource -Module nx 

    Node "localhost"
    {
        nxPackage fortune
        {
            Name = "fortune"
            Ensure = "Present"
            PackageManager = "apt"
        }

        nxPackage cowsay
        {
            Name = "cowsay"
            Ensure = "Present"
            PackageManager = "apt"
        }
    }
}