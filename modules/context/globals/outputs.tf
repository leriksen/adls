output "rbac_propagation_sleep" {
  value = "10s"
}

output "tags" {
  value = {
    project      = "PE"
    project_code = "PE001"
    costcentre   = "00001"
  }
}

output "location" {
  value = "australiasoutheast"
}

output "adls_filesystems" {
  value = toset(
    [
      "staging",
      "forge",
    ]
  )
}

output "adls_paths" {
  value = {
    staging = toset(
      [
        {
          name = "raw",
          acl = [
            {
              scope       = "access",
              id          = "00e67771-2882-40d1-a0c4-899f624ea97d",
              type        = "group",
              permissions = "rwx",
            },
          ]
        },
        {
          name = "curated",
          acl = [
            {
              scope       = "access",
              id          = "00e67771-2882-40d1-a0c4-899f624ea97d",
              type        = "group",
              permissions = "rwx",
            },
          ]
        },
        {
          name = "reference",
          acl = [
            {
              scope       = "access",
              id          = "00e67771-2882-40d1-a0c4-899f624ea97d",
              type        = "group",
              permissions = "rwx",
            },
          ]
        },
      ]
    ),
    forge = toset(
      [
        {
          name = "cooked",
          acl = [
            {
              scope       = "access",
              id          = "00e67771-2882-40d1-a0c4-899f624ea97d",
              type        = "group",
              permissions = "rwx",
            }
          ]
        },
        {
          name = "adhoc",
          acl = [
            {
              scope       = "access",
              id          = "00e67771-2882-40d1-a0c4-899f624ea97d",
              type        = "group",
              permissions = "rwx",
            }
          ]
        },
        {
          name = "indirect",
          acl = [
            {
              scope       = "access",
              id          = "00e67771-2882-40d1-a0c4-899f624ea97d",
              type        = "group",
              permissions = "rwx",
            }
          ]
        },
        {
          name = "into/the/depths",
          acl = [
            {
              scope       = "access",
              id          = "0c5fa7ec-9422-4e96-b2e1-a06f85ab3029",
              type        = "group",
              permissions = "rwx",
            }
          ]
        },
      ]
    ),
  }
}