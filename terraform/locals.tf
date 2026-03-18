locals {
  me = "00e67771-2882-40d1-a0c4-899f624ea97d"

  fs_path = toset(
    flatten(
      [
        for fs in module.global.adls_filesystems : [
          for path in module.global.adls_paths[fs] : format("%s:%s", fs, path.name)
        ]
      ]
    )
  )

  fs_path_acls = merge([
    for fs in module.global.adls_filesystems : {
      for path in module.global.adls_paths[fs] :
      format("%s:%s", fs, path.name) => path.acl
    }
  ]...)
}
