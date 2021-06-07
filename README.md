# GKE + ILB + IAP enabled

## Summary
This repo is an example to configure a Google Internal HTTPS Load Balancer integrated with a GKE web application using the Identity-Aware Proxy to application Authentication and Autorization.

Part of this project is deployed with Terraform and some other configurations completed using Google Cloud Shell and Kubectl commands.

Use the `terraform.tfvars` to set up your GCP project environment variables required for this project.

All the other `.tf` files don't need to be configured, unless you prefer to set up some different configurations.

All the YAML files referred here are included in this repo at `./gke-config` folder

***The project creation, the service API's and the necessary IAM roles to complete the steps, are not covered in this documentation***

---

## STEPS

### -- Automated with Terraform --

**1) Create a GKE cluster**
 - With VPC Native enabled
 - 1 Node for each zone in the region (n1-standard-1 with default CoS image)

**2) Create:**
 - a Proxy-only subnet in the same VPC/region used for GKE
 - a RemoteDesktop VM instance to test the IAP functionality (e2-standard-2 with Debian image)

   ref: https://cloud.google.com/architecture/chrome-desktop-remote-on-compute-engine

 - Firewall rules to access the RDP machine

**3) Enable the necessary API's**
 - Cloud IAP API (iap.googleapis.com)
 - Identity Toolkit API (identitytoolkit.googleapis.com)
 
**4) Configure the OAuth consent screen**

ref: https://console.cloud.google.com/apis/credentials/consent

### -- end Automated with Terraform --

**5) Create the OAuth credentials via Cloud Console**
 - ref: https://console.cloud.google.com/apis/credentials
 - Set OAuth client ID / Web Application
 - then, back to clientID configuration and set the Authorized redirect URIs field like:
  `https://iap.googleapis.com/v1/oauth/clientIds/[CLIENT_ID]:handleRedirect`

 **5.1) Or Through the Cloud Shell**

   `gcloud alpha iap oauth-clients create projects/[PROJECT_ID]/brands/[BRAND-ID] --display_name=[NAME]`
 
### -- Performed through the Cloud Shell --

**6) Get access to the project and GKE cluster**
```
 gcloud config set project [PROJECT_ID]
 gcloud container clusters get-credentials [CLUSTER_NAME] --region [REGION]
 ```
 
**7) Create a Kubernetes secret to IAP**
  - [CLIENT_ID] and [CLIENT_SECRET] created in the step 5
```
 kubectl create secret generic iap-secret --from-literal=client_id=[CLIENT_ID] \
    --from-literal=client_secret=[CLIENT_SECRET]
```

**8) Create a self-signed TLS Certificate to be used with the HTTPS LoadBalancer**

 **8.1) Generate a private key**

 `openssl genrsa -out tls.key 2048`

 **8.2) Create a CSR config file**
   - Fill the `DNS.1` field with your domain name. 
   - Ex: `*.example.com` (using a wildcard) - valid for any prefix host of `example.com` domain
 ```
 cat <<'EOF' >csr_config
[req]
default_bits              = 2048
req_extensions            = extension_requirements
distinguished_name        = dn_requirements

[extension_requirements]
basicConstraints          = CA:FALSE
keyUsage                  = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName            = @sans_list

[dn_requirements]
countryName               = Country Name (2 letter code)
stateOrProvinceName       = State or Province Name (full name)
localityName              = Locality Name (eg, city)
0.organizationName        = Organization Name (eg, company)
organizationalUnitName    = Organizational Unit Name (eg, section)
commonName                = Common Name (e.g. server FQDN or YOUR name)
emailAddress              = Email Address

[sans_list]
DNS.1                     = *.example.com

EOF
```

 **8.3) Generate a CSR file to hereafter sign-in the certificate**
 ```
 openssl req -new -key tls.key \
    -out csr_file \
    -config csr_config
```	
 **8.3.1) Example of inputed fields**

>Country Name (2 letter code) []:ES

>State or Province Name (full name) []:BCN

>Locality Name (eg, city) []:BCN

>Organization Name (eg, company) []:Test

>Organizational Unit Name (eg, section) []:Admin

>Common Name (e.g. server FQDN or YOUR name) []:example.com

>Email Address []:admin@example.com

 **8.4) Create the self-signed TLS file (PEM format):**
 ```
 openssl x509 -req \
    -signkey tls.key \
    -in csr_file \
    -out tls.cert \
    -days 60
```
 **8.5) Check if the file has no error:**
 
 `openssl x509 -in tls.cert -text -noout`


**9) Create the Kubernetes secret with the generated certificate:**

 `kubectl create secret tls tls-secret --cert=tls.cert --key=tls.key`

 **9.1) Check the generated secrets:**
 
   `kubectl get secrets`
   
   
**10) Deploy a basic 'Hello World' web application**

`web-deployment.yaml:`
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: default
spec:
  selector:
    matchLabels:
      run: web
  template:
    metadata:
      labels:
        run: web
    spec:
      containers:
      - image: gcr.io/google-samples/hello-app:1.0
        imagePullPolicy: IfNotPresent
        name: web
        ports:
        - containerPort: 8080
          protocol: TCP 
```
 **10.1) Apply the configuration**

  `kubectl apply -f web-deployment.yaml`
   
**11) Create a Backend configuration to be used with the exposed Service**
 - Defining the IAP enabled

`backend-config.yaml:`
``` 
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: config-default
  namespace: default
spec:
  iap:
    enabled: true
    oauthclientCredentials:
      secretName: iap-secret
```
  **11.1) Apply the configuration**

    `kubectl apply -f backend-config.yaml`

**12) Deploy a Service as a Network Endpoint Group (NEG)**
 - Including a backend-config annotation reference

`web-service.yaml:`
```
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: default
  annotations:
    cloud.google.com/neg: '{"ingress": true}'
    beta.cloud.google.com/backend-config: '{"default": "config-default"}'
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    run: web
  type: NodePort
```
  **12.1) Apply the configuration**

    `kubectl apply -f web-service.yaml`

**13) Deploy an Ingress controller as "gce-internal" class**
 - Mapping the URL to `web.example.com`
 - Setting the TLS secret created before
 
`ilb-ingress.yaml:`
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ilb-ingress
  annotations:
    kubernetes.io/ingress.class: "gce-internal"
    kubernetes.io/ingress.allow-http: "false"
spec:
  tls:
  - hosts:
      - web.example.com
    secretName: tls-secret
  rules:
  - host: web.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 8080
```
  **13.1) Apply the configuration**

    `kubectl apply -f ilb-ingress.yaml`
  
---

Once finished the configuration you might test the IAP functionality connecting throught the RemoteDesktop VM instance created with Terraform, and setting up the `/etc/hosts` with the ILB IP address to resolve to `web.example.com`, for example:

 `echo "10.10.0.10    web.example.com" >> /etc/hosts` 
 
 being `10.10.0.10` the ILB IP address

Then accessing the webpage via browser to https://web.example.com

**Note**: The user must have the ***IAP-secured Web App User*** IAM role permission to get access permission, otherwise it will get the ***Denied*** alert page. I recommend you test the both situations.