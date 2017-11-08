cmd /c ""C:\Program Files\7-Zip\7z.exe" x "C:/Windows/Temp/packer-puppet-masterless/development.7z" -oC:/Windows/Temp/packer-puppet-masterless"

cd C:/Windows/Temp/packer-puppet-masterless
SET FACTER_role=windowswebserver
SET FACTER_packer_build_name=azure-arm
SET FACTER_packer_builder_type=azure-arm

puppet apply --verbose --modulepath='C:/Windows/Temp/packer-puppet-masterless/development/modules;C:/Windows/Temp/packer-puppet-masterless/development/site' --hiera_config='C:/Windows/Temp/packer-puppet-masterless/development/hiera.yaml' C:/Windows/Temp/packer-puppet-masterless/development/manifests/site.pp
exit 0
