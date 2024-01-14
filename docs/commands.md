- Configure mysql remote connections.

```bash
sudo vi /etc/mysql/mariadb.conf.d/50-server.cnf
# change bind address to 0.0.0.0
```

- Make file executable

```bash
chmod +x installer.sh
```

- Git discard all changes on local

```bash
git checkout -f
```

- Delete all completed pods in kubectl

```bash
kubectl delete pod --field-selector=status.phase==Succeeded
```

- Delete all errored pods by:

```bash
kubectl delete pod --field-selector=status.phase==Failed
```
