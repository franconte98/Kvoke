[Torna a README](../../README.md)


## Deployare Keycloak

Analogamente all'OAuth2, l'OpenID Connect adopera un Authorization Provider OIDC per erogare token che forniscono accesso a specifiche risorse. Nel caso di cluster kubernetes, possiamo adoperare questo metodo di autenticazione come alternativa al classico metodo dei certificato x509, che, sebbene siano sicuri, non permettono eventualmente di revocare. 

Entra quindi in gioco la necessità di adoperare un metodo di autenticazione esterno come l'OpenID, e nello specifico adopereremo uno degli OIDC più adoperati, che è keycloak.

Vediamo insieme come funziona prima di proseguire.

![Alt text](Files/OpenID-k8s.png?raw=true "Optional Title")
> Schema di funzionamento dell'OpenID Provider

1) L'User effettua il login.

2) L'OIDC fornisce un `access_token`, `id_token` e `refresh_token`.

3) Adoperando kubectl, su un sistema che ha accesso all'API del cluster, ci connettiamo al cluster, specificando l'`id_token` tramite comando `kubectl --token id_token`.

4) L'`id_token` verrà mandato all'API Server che convalida il JWT, e verifica che non sia scaduto.

5) L'API Server verifica che l'utente sia autorizzato.

6) L'utente riceve una risposta tramite il kubectl.

---

#### Installazione di Keycloak su K8S

Partiamo dal fatto che dobbiamo deployare all'interno del cluster keycloak, che di sè per sè può essere un processo tidioso e complicato. Faremo si che questo sarà deployato in HTTPS tramite un ingress (NGINX), tramite dei certificati generati appositamente. Selezionato il nostro `nome_domain_dns`, possiamo proseguire.

Andiamo a creare i nostri certificati `crt` e `key` tramite il seguente comando apposito.

```
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout keycloak.key -out keycloak.crt -subj "/CN=keycloak" \
  -addext "subjectAltName=DNS:k8s.keycloak.intra,IP:192.168.100.100"
```
>Comando per generare un certificato ed una chiave definendo l'IP su cui esporremo keycloak ed il suo IP (Sarebbe consigliabile adoperare un CA fidato da cui generarlo)

Fatto questo creeremo un secret che prende sia la key che il certificato per adoperarli nell'ingress. Facciamo questo tramite il seguente comando.

```
kubectl create secret tls tls-keycloak -n keycloak --cert=keycloak.crt --key=keycloak.key
```
>Comando per creare Secret di Keycloak

Prima di procedere, consideriamo che i certificati andranno posti all'interno del container in running, e per far ciò possiamo adoperare un init container, che in questo caso andrà ad caricare sia i certificati che i temi. Di seguito il Dockerfile apposito.

```
FROM busybox:latest AS loader

### Create Directories and Load Data
RUN mkdir /data && \
    mkdir -p /opt /opt/keycloak /opt/keycloak/themes /opt/keycloak/data
COPY sismart.zip /data
COPY keycloak.crt /data
COPY keycloak.key /data
```
>Dockerfile per l'initContainer

Fatto questo dobbiamo creare sia il database apposito di Keycloak (Deployato tramite StatefulSet), di seguito il codice apposito.

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: keycloak-db-pvc
  namespace: keycloak
spec:
  ### Dipende da che Dynamic Provisioner vuoi adoperare ###
  storageClassName: longhorn
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 3Gi
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: keycloak-db
  namespace: keycloak
spec:
  replicas: 2
  selector:
    matchLabels:
      servizio: keycloak-db
  template:
    metadata:
      name: keycloak-db
      namespace: keycloak
      labels:
        servizio: keycloak-db
    spec:
      containers:
      - name: keycloak-db
        image: postgres:latest
        securityContext:
          runAsUser: 999
          runAsGroup: 999
        env:
          - name: POSTGRES_USER
            valueFrom:
              secretKeyRef:
                name: keycloak-db-secret
                key: POSTGRES_USER
          - name: POSTGRES_PASSWORD
            valueFrom:
              secretKeyRef:
                name: keycloak-db-secret
                key: POSTGRES_PASSWORD
          - name: POSTGRES_DB
            valueFrom:
              secretKeyRef:
                name: keycloak-db-secret
                key: POSTGRES_DB
          - name: POSTGRES_INITDB_ARGS
            value: "--auth-host=scram-sha-256"
          - name: PGDATA
            value: "/var/lib/postgresql/data/keycloak"
        ports:
          - containerPort: 5432
        volumeMounts:
          - name: keycloak-db-data
            mountPath: /var/lib/postgresql/data
      volumes:
        - name: keycloak-db-data
          persistentVolumeClaim:
            claimName: keycloak-db-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: loadbalancer-keycloak-db
  namespace: keycloak
spec:
  selector:
    servizio: keycloak-db
  ports:
    - name: http
      targetPort: 5432
      port: 5432
  type: LoadBalancer
---
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-db-secret
  namespace: keycloak
type: Opaque
data:
  ### Base64 Encoded ###
  POSTGRES_DB: "a2V5Y2xvYWs="
  POSTGRES_USER: "cG9zdGdyZXM="
  POSTGRES_PASSWORD: "cG9zdGdyZXM="
```
>Yaml di configurazione del DB di Keycloak

Un grande problema di Deployare Keycloak in un cluster Kubernetes, è l'impossibilità di poter deployare più repliche senza una configurazione specifica, essendo che keycloak si definisce di tipo stateful, ed i dati vengono gestiti attraverso un meccanismo di Caching interno (Infinispan). Per cambiare questa cosa è possibile andare a settare tramite configurazione interna ed importando specifici CRDs. Quì vedremo come impostare più repliche di Keycloak per ottenere una configurazione HA.

Per prima cosa installiamo l'Operator di Infinispan per poter deployare i POD che fungeranno da Cache per le nostre repliche di Keycloak. Basterà andare sulla pagine Operator relativa: https://operatorhub.io/operator/infinispan 

Creiamo ora le credenziali per accedere ai Cache tramite le seguenti istruzioni.

```
credentials:
  - username: developer
    password: strong-password
    roles:
      - admin
```
>File `identities.yaml`

```
kubectl create secret generic connect-secret -n keycloak --from-file=identities.yaml
```
>Istruzione per crearci il secret di accesso alla Cache Infinispan

Ora possiamo deployare Infinispan tramite la seguente configurazione.

```
apiVersion: infinispan.org/v1
kind: Infinispan
metadata:
  name: infinispan
  namespace: keycloak
  annotations:
    infinispan.org/monitoring: 'true'
spec:
  replicas: 3
  jmx:
    enabled: true
  security:
    endpointSecretName: connect-secret
  service:
    type: DataGrid
```
>Infinispan.yaml

Attenzione! Potrebbe dare dei problemi all'avvio che sono relativi ai permessi. Per far ciò accedere allo statefulset che è appena stato create e dargli i permessi inserendo un exec di tipo root. Di seguito è mostrato lo spezzone.

```
securityContext:
  runAsGroup: 0
  runAsUser: 0
```
>Security context dello statefulset infinispan da aggiungere in caso di problemi di permessi

A questo punto dobbiamo deployare sul cluster le configurazione dei singoli moduli della cache, che per poter essere esternalizzati devono essere: sessions, actionTokens, authenticationSessions, offlineSessions, clientSessions, offlineClientSessions, loginFailures, and work. Di seguito è mostrata l'intera configurazione.

```
apiVersion: infinispan.org/v2alpha1
kind: Cache
metadata:
  name: sessions
  namespace: keycloak
spec:
  clusterName: infinispan
  name: sessions
  template: |-
    distributedCache:
      mode: "SYNC"
      owners: "2"
      statistics: "true"
      remoteTimeout: "5000"
      encoding:
        media-type: "application/x-protostream"
      locking:
        acquireTimeout: "4000"
      transaction:
        mode: "NON_DURABLE_XA"
        locking: "PESSIMISTIC"
      stateTransfer:
        chunkSize: "16"
      indexing:
        enabled: true
        indexed-entities:
        - keycloak.RemoteUserSessionEntity
---
apiVersion: infinispan.org/v2alpha1
kind: Cache
metadata:
  name: actiontokens
  namespace: keycloak
spec:
  clusterName: infinispan
  name: actionTokens
  template: |-
    distributedCache:
      mode: "SYNC"
      owners: "2"
      statistics: "true"
      remoteTimeout: "5000"
      encoding:
        media-type: "application/x-protostream"
      locking:
        acquireTimeout: "4000"
      transaction:
        mode: "NON_DURABLE_XA"
        locking: "PESSIMISTIC"
      stateTransfer:
        chunkSize: "16"
---
apiVersion: infinispan.org/v2alpha1
kind: Cache
metadata:
  name: authenticationsessions
  namespace: keycloak
spec:
  clusterName: infinispan
  name: authenticationSessions
  template: |-
    distributedCache:
      mode: "SYNC"
      owners: "2"
      statistics: "true"
      remoteTimeout: "5000"
      encoding:
        media-type: "application/x-protostream"
      locking:
        acquireTimeout: "4000"
      transaction:
        mode: "NON_DURABLE_XA"
        locking: "PESSIMISTIC"
      stateTransfer:
        chunkSize: "16"
      indexing:
        enabled: true
        indexed-entities:
        - keycloak.RootAuthenticationSessionEntity
---
apiVersion: infinispan.org/v2alpha1
kind: Cache
metadata:
  name: loginfailures
  namespace: keycloak
spec:
  clusterName: infinispan
  name: loginFailures
  template: |-
    distributedCache:
      mode: "SYNC"
      owners: "2"
      statistics: "true"
      remoteTimeout: "5000"
      encoding:
        media-type: "application/x-protostream"
      locking:
        acquireTimeout: "4000"
      transaction:
        mode: "NON_DURABLE_XA"
        locking: "PESSIMISTIC"
      stateTransfer:
        chunkSize: "16"
      indexing:
        enabled: true
        indexed-entities:
        - keycloak.LoginFailureEntity
---
apiVersion: infinispan.org/v2alpha1
kind: Cache
metadata:
  name: work
  namespace: keycloak
spec:
  clusterName: infinispan
  name: work
  template: |-
    distributedCache:
      mode: "SYNC"
      owners: "2"
      statistics: "true"
      remoteTimeout: "5000"
      encoding:
        media-type: "application/x-protostream"
      locking:
        acquireTimeout: "4000"
      transaction:
        mode: "NON_DURABLE_XA"
        locking: "PESSIMISTIC"
      stateTransfer:
        chunkSize: "16"
---
apiVersion: infinispan.org/v2alpha1
kind: Cache
metadata:
  name: offlinesessions
  namespace: keycloak
spec:
  clusterName: infinispan
  name: offlineSessions
  template: |-
    distributedCache:
      mode: "SYNC"
      owners: "2"
      statistics: "true"
      remoteTimeout: "5000"
      encoding:
        media-type: "application/x-protostream"
      locking:
        acquireTimeout: "4000"
      transaction:
        mode: "NON_DURABLE_XA"
        locking: "PESSIMISTIC"
      stateTransfer:
        chunkSize: "16"
---
apiVersion: infinispan.org/v2alpha1
kind: Cache
metadata:
  name: clientsessions
  namespace: keycloak
spec:
  clusterName: infinispan
  name: clientSessions
  template: |-
    distributedCache:
      mode: "SYNC"
      owners: "2"
      statistics: "true"
      remoteTimeout: "5000"
      encoding:
        media-type: "application/x-protostream"
      locking:
        acquireTimeout: "4000"
      transaction:
        mode: "NON_DURABLE_XA"
        locking: "PESSIMISTIC"
      stateTransfer:
        chunkSize: "16"
---
apiVersion: infinispan.org/v2alpha1
kind: Cache
metadata:
  name: offlineclientsessions
  namespace: keycloak
spec:
  clusterName: infinispan
  name: offlineClientSessions
  template: |-
    distributedCache:
      mode: "SYNC"
      owners: "2"
      statistics: "true"
      remoteTimeout: "5000"
      encoding:
        media-type: "application/x-protostream"
      locking:
        acquireTimeout: "4000"
      transaction:
        mode: "NON_DURABLE_XA"
        locking: "PESSIMISTIC"
      stateTransfer:
        chunkSize: "16"
```
>Caches.yaml

Fatto questo, ed una volta controllato che il database keycloak sia stato creato possiamo scalare lo stateful set e deployare l'applicazione keycloak base per popolare. Di seguito è mostrato il deployment completo con dei commenti. Una volta deployato e che il database è opportunamente popolato possiamo deployare l'app scommentando le parti necessarie nelle variabili di ambiente.

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: keycloak-pvc
  namespace: keycloak
spec:
  storageClassName: longhorn
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: keycloak-themes-pvc
  namespace: keycloak
spec:
  storageClassName: longhorn
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 500Mi
---
apiVersion: v1
kind: Service
metadata:
  name: keycloak
  namespace: keycloak
  labels:
    app: keycloak
spec:
  ports:
    - name: https
      port: 8443
      targetPort: 8443
    - name: http
      port: 8080
      targetPort: 8080
  selector:
    app: keycloak
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  namespace: keycloak
  labels:
    app: keycloak
spec:
  replicas: 1
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      volumes:
        - name: keycloak-themes-pvc
          persistentVolumeClaim:
            claimName: keycloak-themes-pvc
        - name: keycloak-pvc
          persistentVolumeClaim:
            claimName: keycloak-pvc
      containers:
        - name: keycloak
          image: quay.io/keycloak/keycloak:latest
          args: ["start-dev"]
          env:
            #- name: KC_FEATURES
            #  value: "clusterless"
            - name: KC_BOOTSTRAP_ADMIN_USERNAME
              value: admin
            - name: KC_BOOTSTRAP_ADMIN_PASSWORD
              value: admin
            - name: KC_HEALTH_ENABLED
              value: "false"
            - name: KC_DB_URL
              value: jdbc:postgresql://loadbalancer-keycloak-db.keycloak.svc.cluster.local:5432/keycloak
            - name: KC_DB
              value: postgres
            - name: KC_DB_USERNAME
              value: postgres
            - name: KC_DB_PASSWORD
              value: postgres
            - name: KC_HOSTNAME
              value: 172.16.150.206
            - name: QUARKUS_TRANSACTION_MANAGER_ENABLE_RECOVERY
              value: "false"
            #- name: KC_CACHE
            #  value: ispn
            #- name: KC_CACHE_REMOTE_HOST
            #  value: infinispan.keycloak.svc.cluster.local
            #- name: KC_CACHE_REMOTE_PORT
            #  value: "11222"
            #- name: KC_CACHE_REMOTE_USERNAME
            #  value: developer
            #- name: KC_CACHE_REMOTE_PASSWORD
            #  value: strong-password
            #- name: KC_CACHE_REMOTE_TLS_ENABLED
            #  value: "false"
            #- name: KC_CACHE_STACK
            #  value: kubernetes
          volumeMounts:
            - name: keycloak-themes-pvc
              mountPath: /opt/keycloak/themes
            - name: keycloak-pvc
              mountPath: /opt/keycloak/data
          ports:
            - name: http
              containerPort: 8080
            - name: https
              containerPort: 8443
```
>Keycloak

Adoperando keycloak possiamo anche cambiare il metodo di autenticazione per kubernetes, passando da un obsoleto sistema ad
autenticazione interna ad uno ad autenticazione esterna con un OIDC opensource. L'unica grande pecca di keycloak
è l'impossibilità di poter deployare più di una replica dato che keycloak è un'applicazione stateful (Potremmo esternalizzare la cache
Infinispan, ma costituirebbe un collo di bottiglia notevole), ma se deployato una sola replica keycloak risulta 
minimalistica e perfetta.

Andiamo per step per poter spiegare opportunamente come poter implementare una soluzione ideale per ambienti 
di produzione.

<ins>Step 1)</ins> Configurazione interna di Keycloak.

Prima di tutto creiamo un Realm personalizzato dedicato puramente all'autenticazione con l'API Server, ad esempio 
un realm di nome `k8s-auth`. Al suo interno consideriamo il cluster kubernetes come un Client, e ne creeremo 
uno nello spazione apposito in `Clients`, che chiameremo `k8s`.

![Alt text](Files/Client-1.png?raw=true "Optional Title")

![Alt text](Files/Client-2.png?raw=true "Optional Title")

![Alt text](Files/Client-3.png?raw=true "Optional Title")

> Screenshots della creazione del Client 

A questo punto dovremo creare un `Client Scope` per poter associare i futuri utenti che vorremo creare rispetto al Client `k8s`. Lo chiameremo come vogliamo, ma in questo caso si chiamerà `groups`. 

![Alt text](Files/Client-Scope-1.png?raw=true "Optional Title")

![Alt text](Files/Client-Scope-2.png?raw=true "Optional Title")

> Screenshots della creazione del Client Scope

Ora potremo creare liberamente i nostri `User`, che potremo completamente gestire attraverso keycloak. Iniziamo creando un utente `user-prova`, configurandolo ed aggiungendolo al `Client Scope`. Questo permette di bindare un utente rispetto al client, che in questo caso è Kubernetes.

![Alt text](Files/User-1.png?raw=true "Optional Title")

![Alt text](Files/User-2.png?raw=true "Optional Title")

> Screenshots della creazione del Client Scope

Fatto questo Keycloak è pronto ad essere adoperato come oidc provider per l'autenticazione all'Api Server, dovremo quindi configurare il resto.

<ins>Step 2)</ins> Configurazione del Cluster.

A questo punto dovremo dichiarare l'oidc all'interno dell'Api Server, configurandolo correttamente. Andremo quindi a modificare il file di configurazione, che nel nostro caso, adoperando kubeadm, è `/etc/kubernetes/manifests/kube-apiserver.yaml`. 
All'interno inseriremo le seguenti righe.

```
 - command:
    .......
    ### Indirizzo dell'oidc issuer ###
    - --oidc-issuer-url=https://192.168.131.109:8443/realms/k8s-auth 
    ### Nome del Client ###
    - --oidc-client-id=k8s
    ### Parametro da adoperare per l'autenticazione ###
    - --oidc-username-claim=name
    ### Nome del Client Scope ###
    - --oidc-groups-claim=groups
    ### Certificato adoperato per l'HTTPS di keycloak ###
    - --oidc-ca-file=/etc/kubernetes/pki/keycloak.crt
```
>Righe di configurazione dell'OIDC per l'api-server

Al termine andiamo ad effettuare un reload ed applicare i cambiamenti tramite il restart del kubelet. Seguiamo le seguenti istruzioni.

```
systemctl daemon-reload
systemctl restart kubelet
```
> Comandi di gestione del kubelet

Fatto questo il cluster dovrebbe essere pronto per poter accogliere richieste da un utente esterno, dichiarato all'interno di Keycloak.

Ora ci toccherà andare a definire dei ruoli ed eseguire un binding rispetto agli utenti creati. Piuttosto che associare gli utenti, quì andiamo ad associare il `Client Scope`, nel nostro esempio groups.. Di seguito vi è un esempio.

```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-svc
rules:
  - apiGroups: [""]
    resources: ["pods", "services"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: keycloak-binding
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: Group
    name: groups
roleRef:
  kind: ClusterRole
  name: pod-svc
  apiGroup: rbac.authorization.k8s.io
```

<ins>Step 3)</ins> Configurazione dell'User.

A questo punto, sia Keycloak che il cluster sono pronti a stabilire una connessione, ma come faremo a configurare l'User correttamente? Come tool per gestire il cluster adopereremo `kubectl` all'interno di un host linux che riesce a connettersi sia a keycloak che all'api-server. Per poterci autenticare adopereremo, invece, il `KubeConfig`, in maniera analoga a come abbiamo visto in precedenza. 

In questo caso, però, l'autenticazione da parte dell'utente avrà delle modifiche. Di seguito vi è un esempio.

```
apiVersion: v1
clusters:
- cluster:
    ### Certificato .crt del cluster + Indirizzo al Kube Api Server ###
    certificate-authority-data: DATA+OMITTED
    server: https://192.168.131.50:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    namespace: all
    user: user-prova
  name: user-prova@kubernetes
current-context: user-prova@kubernetes
kind: Config
preferences: {}
users:
- name: user-prova
  user:
    auth-provider:
      config:
        ### Client-Id preso dal Client ###
        client-id: k8s
        ### Client-Secret preso dal Client ###
        client-secret: g1KYQbLZsDkNJGEOnvY4n40SAuJh64bO
        ### ID-Token della request ###
        id-token: ID_TOKEN_PRESO_DA_REQUEST
        ### Indirizzo dell'issuer (Stesso della conf Api)###
        idp-issuer-url: https://192.168.131.109:8443/realms/k8s-auth
        ### Refresh-Token della request ###
        refresh-token: REFRESH_TOKEN_PRESO_DA_REQUEST
      name: oidc
```

Come noteremo, due campi, che sono l'`ip-token` ed il `refresh-token` vengono a seguito di una richiesta a Keycloak. Questo, nello specifico può essere fatto in varii modi, come una curl o una POST su Postman. Di seguto vi è la curl completa.

```
curl -k -d "client_id=k8s" \
        -d "client_secret=tXkCXzCkQaz1j59mOrcNb7uaSajqOs7u" \
        -d "username=user-prova" \
        -d "password=password" \
        -d "scope=openid" \
        -d "grant_type=password" \
        https://192.168.131.109:8443/realms/k8s-auth/protocol/openid
```

Riceveremo un JWT che contiene l'`ip-token` ed il `refresh-token`, che adopereremo nel nostro kubeconfig. Tramite le seguenti istruzioni andiamo ad esportare il kubeconfig in kubectl ed a verfiicare i ruoli.

```
export KUBECONFIG=/path/to/config

kubectl auth can-i --list
```

A questo punto potremo accedere a tutti i ruoli definiti all'interno del cluster da parte degli amministratori attraverso un comodo kubeconfig. A differenza dei metodi precedenti, quì abbiamo pieno controllo rispetto agli utenti, e potremo quindi attivarli e disattivarli a nostro completo piacimento! Inoltre, l'architettura OpenID permette di avere un livello elevato di sicurezza, e di averte un'alternativa ai vecchi metodi di autenticazione interna.

---