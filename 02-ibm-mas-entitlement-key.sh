export ENTITLEDKEY="$(<./keyfiles/ibm-entitlement-key)"
export NAMESPACE="mas-max-manage"
oc create secret docker-registry ibm-entitlement  --docker-server=cp.icr.io --docker-username=cp --docker-password=${ENTITLEDKEY} --namespace=${NAMESPACE}
