# Laboratorio: Escalado en Kubernetes con Flask

Aplicación Flask desplegada en Kubernetes con un Deployment y un Service NodePort, para practicar escalado manual (imperativo y declarativo), balanceo de carga entre Pods, autorreparación y autoescalado con HPA.

Guía: [laboratorio_kubernetes.md](https://github.com/wils0n/laboratorios-md/blob/main/laboratorio_kubernetes/laboratorio_kubernetes.md)

## Estructura

```
.
├── app/
│   ├── app.py              # Flask: responde con el nombre del Pod
│   ├── requirements.txt
│   └── Dockerfile
├── k8s/
│   ├── 01-deployment.yaml  # Deployment (réplicas, readinessProbe, resources)
│   └── 02-service.yaml     # Service NodePort 30080
├── scripts/
│   └── balanceo.sh         # N peticiones y conteo por Pod
├── kind-config.yaml        # Clúster local kind con el puerto 30080 mapeado
└── README.md
```

## Entorno

- Windows 11, Docker Desktop 29.x
- Clúster local con [kind](https://kind.sigs.k8s.io/) (Kubernetes v1.37). `kind-config.yaml` mapea el NodePort 30080 a `localhost:30080`, así que el comportamiento es el mismo que en Docker Desktop u OrbStack.

## Cómo ejecutarlo

```bash
# 1. Clúster
kind create cluster --config kind-config.yaml
kubectl get nodes

# 2. Imagen (kind no ve las imágenes locales: hay que cargarla)
docker build -t flask-k8s-app:1.0 ./app
kind load docker-image flask-k8s-app:1.0 --name lab-k8s

# 3. Despliegue
kubectl apply -f k8s/
kubectl get pods -o wide

# 4. Balanceo
./scripts/balanceo.sh 10
```

Para desarrollo local sin Kubernetes:

```bash
python -m venv .venv
source .venv/Scripts/activate      # Windows (Git Bash). En Linux/macOS: .venv/bin/activate
pip install -r app/requirements.txt
python app/app.py                  # http://localhost:5000
```

## Resultados

| Parte | Qué se hizo | Resultado |
|---|---|---|
| 2.1 | Deployment con 2 réplicas | `READY 2/2`, 2 Pods `Running 1/1` |
| 2.3 | `./scripts/balanceo.sh 10` | 5 / 5 peticiones repartidas entre los 2 Pods |
| 3.1 | `kubectl scale --replicas=5` | `READY 5/5`, 5 IPs en el EndpointSlice; los 5 Pods atienden tráfico |
| 3.2 | `replicas: 3` en el YAML + `kubectl apply` | 2 Pods pasan a `Terminating`, queda `3/3` |
| 3.3 | `kubectl delete pod` | El ReplicaSet crea un Pod nuevo en segundos |
| 3.4 | `kubectl scale --replicas=0` | Sin Pods ni endpoints, el Service no responde; Deployment y Service siguen existiendo |
| 5 | HPA `--cpu=50% --min=2 --max=6` con 2 generadores de carga | La CPU sube a 187 % del request y `REPLICAS` pasa de 3 a 4 y luego a 6 |

Las capturas del informe están en `imagenes/`, que está en `.gitignore`.

### Notas

- **El reparto no es exacto.** kube-proxy elige un Pod al azar por conexión: con 20 peticiones a veces aparecen solo 4 de los 5 Pods, y con 30 aparecen todos.
- **El YAML es la fuente de verdad.** Después de `kubectl scale --replicas=5`, un `kubectl apply` del manifiesto vuelve a `replicas: 3`.
- **HPA en kind.** metrics-server necesita `--kubelet-insecure-tls`. Un solo generador `busybox` no bastó para superar el 50 %, así que se usaron dos.
- **Git Bash en Windows.** Convierte `/bin/sh` en `C:/Program Files/Git/usr/bin/sh` dentro de `kubectl run ... -- /bin/sh -c ...`. Hay que exportar `MSYS_NO_PATHCONV=1` antes.

## Limpieza

```bash
kubectl delete hpa flask-app
kubectl delete -f k8s/
kind delete cluster --name lab-k8s
```
