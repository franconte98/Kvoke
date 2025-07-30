[Torna a README](../../../README.md)


## Deployare ArgoCD

Per procedere con l’istallazione, abbiamo bisogno di Homebrew, un install tool messo a disposizione per linux che adopereremo per scaricare argoCD. Basterà eseguire il seguente comando e seguire le istruzioni che verranno date.
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
Una volta fatto ciò, possiamo procedere. Andiamo ad eseguire l’installazione di argoCD cli tramite la seguente istruzione.
```
brew install argocd
```
Il nostro cluster kubernetes è quindi pronto per eseguire argoCD. Eseguiamo quindi i seguenti comandi.
```
kubectl create namespace argocd

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```
Accediamo al servizio di argoCD tramite un cambio di servizio da ClusterIP a LoadBalancer. Per far ciò inseriamo il seguente comando.
```
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```
E’ ora possibile accedere ad argoCD tramite browser all’indirizzo assegnato. Una volta navigato a quell’indirizzo dal nostro browser ci ritroveremo in una pagina che richiederà di accedere tramite delle credenziali. Quì:

<ins>Username:</ins> admin

<ins>Password:</ins> La ottieni andando a decryptare da base64 il secret argocd-initial-admin-secret. 