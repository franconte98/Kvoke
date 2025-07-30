[Torna a README](../../README.md)

## Deployare il Metrics-Server

Componente fondamentale per avere le metriche dei nostri POD e dei nostri servizi. L'installazione è minimale ma bisogna bipassare il TLS per farlo effettivamente funzionare. 

```
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm fetch metrics-server/metrics-server --untar
```
> Install Metrics Server and Untar it

Ora dobbiamo modificare i `values.yaml` ed inserire la seguente istruzione per poter avere metrics-server inizialmente e skippare la verifica TLS con il Kubelet

```
defaultArgs:
  - --kubelet-insecure-tls
```
> Workaround to Enable metrics-server initially

Fatto ciò andiamo ad installare metrics server.

```
helm install metrics-server metrics-server --create-namespace -n metrics
```