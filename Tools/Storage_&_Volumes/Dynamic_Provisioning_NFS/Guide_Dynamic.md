[Torna a README](../../../README.md)

## Dynamic Provisioning NFS

Il dynamic provisioning è una funzionalità straordinaria di k8s dato che permette di allocare dei Volumi persistenti automaticamente andando a dichiarare dei PVC. E' possibile farlo con tantissime tecnologie, ma la più rilevante è l'NFS. Nello specifico, di seguito sono mostrare le istruzioni con parametri ed in quale tipo di nodo andare ad inizializzarle.

`In ogni Nodo`, indicando la directory dell'NFS.
```
chmod +x Setup-Init.sh
bash -xv Setup-Init.sh /directory/dell/nfs
```

`In ogni Master`, indicando la directory dell'NFS e poi l'IP dell'NFS Server
```
chmod +x Setup-Final.sh
bash -xv Setup-Final.sh /directory/dell/nfs IP_NFS_Server
```

Una volta fatto andiamo a testarlo, basta andare a crearsi un PVC di prova come mostrato di sotto.

```
kubectl apply -f test-nfs.yml
```
---
