[Torna a README](../../../README.md)

## Longhorn

Andiamo prima di tutto ad installare longhorn tramite i file di configurazione posti quì all'interno. Per prima cosa andiamo ad installare le componenti tramite i seguenti comandi.

```
chmod +x Install.sh && bash -xv Install.sh
```

Fatto questo, andiamo a settare l'interfaccia grafica su cui esporre il nostro servizio. Ci servono delle credenziali, ma la password da inserire deve essere codificata attraverso il comando `openssl passwd -stdin -apr1 <<< password_da_codificare`. Fatto questo creiamo un file di nome `auth` da cui creare il secret per la configurazione come mostrato di seguito.

```
username:password_codificata
```
>File `auth` contenente le credenziali per accedere a longhorn

Creiamo il secret attraverso la seguente istruzione.

```
kubectl -n longhorn-system create secret generic basic-auth --from-file=auth
```

Ora creeremo l'ingress che esporra' il servizio dashboard di Longhorn, che e' come mostrato di seguito.

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longhorn-ingress
  namespace: longhorn-system
  annotations:
    # type of authentication
    nginx.ingress.kubernetes.io/auth-type: basic
    # prevent the controller from redirecting (308) to HTTPS
    nginx.ingress.kubernetes.io/ssl-redirect: 'false'
    # name of the secret that contains the user/password definitions
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    # message to display with an appropriate context why the authentication is required
    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required '
    # custom max body size for file uploading like backing image uploading
    nginx.ingress.kubernetes.io/proxy-body-size: 10000m
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: longhorn-frontend
            port:
              number: 80
```
>File dell'ingress

<ins>TIP:</ins> Affinche possa essere effettivamente esposto, vi deve essere un ingress controller all'interno del cluster, ma se il cluster è stato inizializzato quì è già incluso.

A questo punto navighiamo sull'indirizzo dell'ingress controller (porta 80), e ci troveremo su uno schermo di login in cui indichiamo le nostre credenziali. Installato!

---