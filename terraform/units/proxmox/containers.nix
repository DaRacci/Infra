# This file gets rendered to `terraform/units/proxmox/containers.tf.json`.
#
# Every container starts from `defaults`; overrides are deep-merged on top.
# Lists REPLACE rather than merge, so mount_point / device_passthrough are always wholesale definitions.
{
  lib,
}:
let
  secureMountOptions = [
    "noatime"
    "lazytime"
    "nodev"
    "noexec"
    "nosuid"
  ];

  # TODO: can't remember where these magic uid and gid came from
  rocmPassthrough = [
    {
      uid = 0;
      gid = 26;
      mode = "0660";
      path = "/dev/dri/renderD128";
    }
    {
      uid = 0;
      gid = 303;
      mode = "0660";
      path = "/dev/kfd";
    }
  ];

  defaults = {
    node_name = "proxmox";
    unprivileged = true;
    start_on_boot = true;
    started = true;

    operating_system = {
      template_file_id = "";
      type = "nixos";
    };

    initialization = {
      ip_config = [
        {
          ipv4 = [
            { address = "dhcp"; }
          ];
          ipv6 = [
            { address = "dhcp"; }
          ];
        }
      ];
    };

    console = {
      enabled = true;
      type = "console";
      tty_count = 2;
    };

    cpu = {
      cores = 2;
      limit = 0;
      units = 1024;
    };

    memory = {
      dedicated = 2048;
      swap = 0;
    };

    features = {
      nesting = true;
      fuse = false;
    };

    disk = {
      datastore_id = "local-zfs";
      size = 16;
    };

    network_interface = [
      {
        name = "eth0";
        bridge = "vmbr0";
      }
    ];

    mount_point = [ ];
    device_passthrough = [ ];
  };

  # Legacy Containers without a template_file_id,
  # their remote state has `""` baked in, so they must keep it to avoid forced recreation.
  legacyContainers = [
    "nixai"
    "nixarr"
    "nixcloud"
    "nixdev"
    "nixio"
    "nixmon"
    "nixserv"
  ];

  container =
    name: overrides:
    lib.recursiveUpdate defaults (
      {
        initialization.hostname = name;
        operating_system.template_file_id =
          if lib.elem name legacyContainers then "" else "local:vztmpl/${name}.tar.xz";
      }
      // overrides
    );
in
{
  nixserv = container "nixserv" {
    cpu = {
      cores = 8;
      units = 80;
    };

    memory.dedicated = 8192;

    mount_point = [
      {
        volume = "local-zfs";
        path = "/nix/store";
        size = "128G";
        backup = false;
      }
    ];
  };

  nixdev = container "nixdev" {
    cpu = {
      cores = 8;
      units = 105;
    };

    memory.dedicated = 16384;
    disk.size = 32;
    features.fuse = true;

    mount_point = [
      {
        volume = "local-zfs";
        path = "/var/lib/coder";
        size = "128G";
        backup = false;
      }
    ];
  };

  nixio = container "nixio" {
    cpu = {
      cores = 6;
      units = 120;
    };

    memory.dedicated = 4096;
    features.fuse = true;

    mount_point = [
      {
        volume = "local-zfs:subvol-105-disk-1";
        path = "/var/lib/minio/data";
        size = "512G";
        backup = false;
      }
      {
        volume = "fast";
        path = "/var/lib/seaweedfs";
        size = "512G";
        backup = false;
      }
    ];
  };

  nixarr = container "nixarr" {
    cpu = {
      cores = 4;
      units = 90;
      limit = 200;
    };

    memory = {
      dedicated = 12288;
      swap = 2048;
    };

    disk.size = 24;
    device_passthrough = rocmPassthrough;

    mount_point = [
      {
        volume = "fast";
        path = "/data/media";
        size = "4156G";
        backup = false;
        mount_options = [ "noatime" ];
      }
    ];
  };

  nixcloud = container "nixcloud" {
    cpu = {
      cores = 8;
      units = 110;
    };

    memory = {
      dedicated = 16384;
      swap = 4096;
    };

    disk.size = 32;
    features.fuse = true;

    mount_point = [
      {
        volume = "/fast/subvol-106-disk-0";
        path = "/mnt/media/";
        read_only = true;
        backup = false;
        mount_options = [
          "noatime"
          "lazytime"
        ];
      }
    ];
  };

  nixmon = container "nixmon" {
    cpu = {
      cores = 2;
      units = 75;
    };

    memory = {
      dedicated = 8192;
      swap = 2048;
    };

    features.fuse = true;

    mount_point = [
      {
        volume = "fast:subvol-108-disk-0";
        path = "/var/lib/prometheus2";
        size = "32G";
        backup = true;
        mount_options = secureMountOptions;
      }
      {
        volume = "fast:subvol-108-disk-1";
        path = "/var/lib/loki";
        size = "8G";
        backup = false;
        mount_options = secureMountOptions;
      }
    ];
  };

  nixai = container "nixai" {
    cpu = {
      cores = 16;
      units = 75;
      limit = 100;
    };

    memory = {
      dedicated = 24576;
      swap = 2048;
    };

    disk.size = 96;
    device_passthrough = rocmPassthrough;

    mount_point = [
      {
        volume = "fast:subvol-103-disk-0";
        path = "/var/lib/hermes";
        size = "64G";
        backup = true;
      }
    ];
  };

  nixstor = container "nixstor" {
    cpu = {
      cores = 8;
      units = 100;
    };

    memory.dedicated = 8192;
    disk.size = 16;

    mount_point = [
      {
        volume = "fast";
        path = "/var/lib/seaweedfs";
        size = "1T";
        backup = false;
      }
    ];
  };

  nixdb = container "nixdb" {
    cpu = {
      cores = 4;
      units = 100;
    };

    memory.dedicated = 4096;
    disk.size = 16;

    mount_point = [
      {
        volume = "fast";
        path = "/var/lib/postgresql";
        size = "64G";
        backup = true;
        mount_options = secureMountOptions;
      }
      {
        volume = "fast";
        path = "/var/lib/postgresql/backup";
        size = "64G";
        backup = false;
        mount_options = secureMountOptions;
      }
    ];
  };

  nixauth = container "nixauth" {
    cpu = {
      cores = 2;
      units = 100;
    };

    memory.dedicated = 1024;
    disk.size = 8;

    mount_point = [
      {
        volume = "fast";
        path = "/var/lib/kanidm";
        size = "4G";
        backup = true;
        mount_options = secureMountOptions;
      }
      {
        volume = "fast";
        path = "/var/lib/kanidm/backup";
        size = "4G";
        backup = false;
        mount_options = secureMountOptions;
      }
    ];
  };
}
