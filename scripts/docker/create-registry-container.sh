#! /bin/sh

set -x
set -o errexit

kind_version=$(kind version)
reg_name='kind-registry'


# create registry container unless it already exists
running="$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)"
if [ "${running}" != 'true' ]; then
  docker run \
    -d --restart=always -p "5000:5000" --name "${reg_name}" \
    registry:2
fi


reg_host="$(docker inspect -f '{{.NetworkSettings.IPAddress}}' "kind-registry")"
echo "Registry Host: ${reg_host}"


containers=$(docker network inspect kind -f "{{range .Containers}}{{.Name}} {{end}}")
needs_connect="true"
for c in $containers; do
  if [ "$c" = "${reg_name}" ]; then
    needs_connect="false"
  fi
done
if [ "${needs_connect}" = "true" ]; then
  docker network connect "kind" "${reg_name}" || true
fi
