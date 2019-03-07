#!/bin/bash
# Setup Preliminary Info
src_location='westus2'
src_rg_name='my-source-rg'
src_vm_name='my-golden-vm'
dst_location='eastus'
dst_rg_name='my-eastus-demo-rg'
dst_snap_name='my-snapshot-name'

tmp_rg_name='temp-migrate-rg'
src_snap_name='temp-snapshot'
copy_time=3600
container_name='snapshots'
storage_sku='Standard_LRS'
blob_name="$src_snap_name.vhd"


dst_len=${#dst_location}
rand_len=$((24-$dst_len))
uuid=$(head /dev/urandom | tr -dc a-z0-9 | head -c $rand_len)

sta_name="$dst_location$uuid"

# Create temp rg
az group create --name $tmp_rg_name --location $dst_location

# Create snapshot
vm_obj=`az vm show -g $src_rg_name -n $src_vm_name`
src_disk_id=$(echo $vm_obj | /usr/bin/jq --raw-output '.storageProfile.osDisk.managedDisk.id')
az snapshot create --name $src_snap_name --resource-group $tmp_rg_name --location $src_location --sku Standard_LRS --source $src_disk_id

# Create snapshot access URL
snap_url=`az snapshot grant-access --name $src_snap_name --resource-group $tmp_rg_name --duration-in-seconds $copy_time`
snap_url=$(echo $snap_url | /usr/bin/jq --raw-output '.accessSas')

# Create storage account/container in target region
az storage account create --name $sta_name --resource-group $tmp_rg_name --location $dst_location --sku $storage_sku
az storage container create --name $container_name --account-name $sta_name

# Get Storage Key and Generate SAS Token
key_obj=`az storage account keys list --account-name $sta_name --resource-group $tmp_rg_name`
key1=$(echo $key_obj | /usr/bin/jq --raw-output '.[0].value')

end=`date -d "60 minutes" '+%Y-%m-%dT%H:%MZ'`
sas_token=`az storage account generate-sas --account-name $sta_name --account-key $key1 --expiry $end --permissions 'aclrpuw' --resource-types 'sco' --services 'b' --https-only`
sas_token=$(echo $sas_token | tr '"' "'")

# Start blob copy
az storage blob copy start --source-uri $snap_url --destination-blob $blob_name --destination-container $container_name --account-name $sta_name --sas-token $sas_token

# This copy will take some time... we can check with:
az storage blob show --name $blob_name --container-name $container_name --account-name $sta_name

# Create Snapshot in regional rg
snap_vhd_uri=`az storage blob url --name $blob_name --container-name $container_name --account-name $sta_name`
snap_vhd_uri=$(echo $snap_vhd_uri | tr -d '"')
az snapshot create --resource-group $dst_rg_name --name $dst_snap_name --location $dst_location --sku $storage_sku --source $snap_vhd_uri

# We will then use the snapshot to create a disk, and attach a disk to the VM during creation time. We can also deploy both these through a template based approach for consistency and customization.
az disk create --resource-group $dst_rg_name --name <my-disk-name> --source $dst_snap_name --location $dst_location
az vm create --resource-group $dst_rg_name --name <replica-vm-name> --attach-os-disk <my-disk-name> --os-type Windows