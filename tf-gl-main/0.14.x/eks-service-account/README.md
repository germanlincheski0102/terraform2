See examples for example.

Usage:
# Create and apply module (refer to example, be sure to specify valid primary policy)
# Make a note of output `role_arn` and put into K8S service account manifests, e.g.,
```
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    name: flux
  name: flux
  namespace: fluxcd
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::1234567890:role/flux-flucd-123456
```
