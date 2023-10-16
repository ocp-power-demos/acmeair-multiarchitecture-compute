### Acme Air Sample Application for Multi-architecture Compute

This application shows an implementation of a fictitious airline called "Acme Air" to exercise OpenLiberty JEE Profile with MongoDB as a datastore. This repository is used to highlight various Multi-architecture compute scenarios.

The application is forked from https://github.com/blueperf/acmeair-multiarchitecture-compute

The application depends on: 

```
mongodb     | 4.4.18 | podman pull icr.io/ppc64le-oss/mongodb-ppc64le:4.4.18
openliberty | latest | podman pull icr.io/appcafe/open-liberty:kernel-slim-java11-openj9-ubi
ubi-minimal | latest | podman pull registry.access.redhat.com/ubi8/ubi-minimal
```

### Build
Use maven to build the project
 - git clone https://github.com/ocp-power-demos/acmeair-multiarchitecture-compute
 - cd acmeair-multiarchitecture-compute
 - cd source && mvn clean package && cd ..

Note, if you are on a mac, you can setup maven using `brew install maven` and `dnf install -y maven.noarch java-11-openjdk.x86_64`
Note, the tests are commented out as they depend on out-of-date MongoDb test dependencies.
 
### Setup

1. Clone this repository 

```
❯ git clone https://github.com/ocp-power-demos/acmeair-multiarchitecture-compute.git
```

2. Create the MONGODB user and encode to base64.

```
❯ export MONGODB_USER=admin
```

3. Create the MONGODB password and encode to base64. (an example of admin)

```
❯ export MONGODDB_PASS=admin
```

4. Make a secret file that is going to get loaded.

```
❯ cat << EOF > ./manifests/base/env.secret
username=${MONGODB_USER}
password=${MONGODB_PASS}
EOF
```

5. Download kustomize from [https://github.com/kubernetes-sigs/kustomize/releases/latest](https://github.com/kubernetes-sigs/kustomize/releases/latest)

```
❯ curl -o kustomize.tar.gz -L https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.1.0/kustomize_v5.1.0_darwin_amd64.tar.gz
❯ tar xvf kustomize_v5.1.0_darwin_amd64.tar.gz
```

6. Run the kustomize for single-arch (Intel only) and does not use node-selectors. This use-case is single architecture Intel only without nodeSelectors. It will fail when scheduled on a Power node.

```
❯ kustomize build manifests/overlays/single-arch-intel | oc apply -f -
project.project.openshift.io/acmeair created
service/acmeair-http created
service/acmeair-https created
route.route.openshift.io/acmeair created
horizontalpodautoscaler.autoscaling/acmeair-java-autoscaler created
service/acmeair-db created
secret/mongodb-config created
secret/mongodb-creds created
deployment.apps/acmeair-multiarchitecture-compute-deployment created
deployment.apps/acmeair-db created
```

7. Run the kustomize for single-arch (PowerPC only). This use-case is single architecture Power only with nodeSelectors so that it will not run on Intel.

```
❯ ./kustomize build manifests/overlays/single-arch-power | oc apply -f -
```

8. Run the kustomize for multi-arch (non-OpenStack)

```
❯ kustomize build manifests/overlays/multi-arch | oc apply -f -
```

9. Run the kustomize for multi-arch (OpenStack)

```
❯ kustomize build manifests/overlays/multi-arch-openstack | oc apply -f -
```

10. Run the kustomize for multi-arch (PowerVS) using EmptyDir

```
❯ kustomize build manifests/overlays/multi-arch-powervs-empty | oc apply -f -
```

11. Run the kustomize for ibmcloud using nfs

```
❯ kustomize build manifests/overlays/ibmcloud | oc apply -f -
```

This one uses an empty dir, when the Pod is destroyed the local data is destroyed.

Note, you may need to run `oc apply -f manifests/overlays/multi-arch-openstack/storageclass.yaml`.

If the app does not work, make sure you setup the .env.secret file.

### Database Load

1. Find the Route to the AcmeAir Route

```
❯ export ACMEAIR_ROUTE=$(oc get route acmeair -ojsonpath='{.status.ingress[0].host}' -n acmeair)
```

2. Find the Path to the Loader and open the URL. You must use https://

```
❯ echo "https://${ACMEAIR_ROUTE}/loader.html"
https://acmeair.local.ocp-multiarch.xyz/loader.html
```

3. Click **Load the database**

4. Confirm the Successful Load. You should see no HTTP error codes.

Note, you'll need to Accept any Certificate Warning.

## Use

1. Navigate to index.html

2. Click Login

3. Enter uid0@email.com and Click OK

4. Try Booking and Canceling a Flight

## Contributing

If you have any questions or issues you can create a new [issue here][issues].

Pull requests are very welcome! Make sure your patches are well tested.
Ideally create a topic branch for every separate change you make. For
example:

1. Fork the repo
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

All source files must include a Copyright and License header. The SPDX license header is 
preferred because it can be easily scanned.

If you would like to see the detailed LICENSE click [here](LICENSE).

```text
#
# Copyright 2023 - IBM Corporation. All rights reserved
# SPDX-License-Identifier: Apache-2.0
#
```

# Support
Is this a Red Hat or IBM supported solution?

No. This is only an sample application for Multi Architecture Compute.

# Notes
The code may not use https://www.mongodb.com/docs/drivers/java/sync/current/fundamentals/connection/connect/
Thanks for DevOpsCube for https://devopscube.com/deploy-mongodb-kubernetes/
[link to the Power Container Registry](https://community.ibm.com/community/user/powerdeveloper/blogs/priya-seth/2023/04/05/open-source-containers-for-power-in-icr)
