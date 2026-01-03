path "sys/auth" { capabilities = ["read","list"] }
path "sys/auth/*" { capabilities = ["create","read","update","delete","list","sudo"] }

path "auth/kubernetes/*" { capabilities = ["create","read","update","delete","list","sudo"] }
path "auth/token/lookup-self" { capabilities = ["read"] }

path "sys/mounts" { capabilities = ["read","list"] }
path "sys/mounts/*" { capabilities = ["create","read","update","delete","list","sudo"] }

path "sys/policies/acl" { capabilities = ["read","list"] }
path "sys/policies/acl/*" { capabilities = ["create","read","update","delete","list","sudo"] }

# Allow clients (including Terraform provider) to introspect token capabilities.
path "sys/capabilities-self" { capabilities = ["update"] }

# Some clients read this for mount discovery.
path "sys/internal/ui/mounts" { capabilities = ["read"] }
