[Torna a README](../../../README.md)


## Deployare Harbor

Adoperiamo Helm come strumento per l'installazione internamente. Nello specifico dovremo modificare internamente i values del chart per poterlo rendere operativo all'interno del cluster prima di proseguire. Vediamo come fare.

```
helm repo add harbor https://helm.goharbor.io
helm fetch harbor/harbor --untar
```
> Install Harbor ed untar it in a directory

Una volta aperto dovremo modificare i campi necessari, di cui alcuni sono:
 
- Storage Class: Inserire lo storage class da usare in `persitence.storageClass`

- Hostname: Si inserisce nei campi `externalURL` e `ingress.hosts.core`.

Fatto questo possiamo installarlo nel nostro cluster tramite la seguente istruzione.

```
helm install --name harbor harbor/ --create-namespace --namespace harbor
```
> Comand to Install Harbor through Helm