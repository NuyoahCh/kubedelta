package extender

import (
	"context"
	"fmt"
	"time"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/informers"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/cache"
)

// RunBindWatcher 在 Pod 绑定到节点后写入 task-id 注解（PostBind 等价逻辑）。
func RunBindWatcher(ctx context.Context, client kubernetes.Interface) {
	factory := informers.NewSharedInformerFactory(client, 30*time.Second)
	informer := factory.Core().V1().Pods().Informer()
	informer.AddEventHandler(cache.ResourceEventHandlerFuncs{
		UpdateFunc: func(_, obj any) {
			pod, ok := obj.(*corev1.Pod)
			if !ok || pod.Spec.NodeName == "" || pod.Annotations[AnnotationTaskID] != "" {
				return
			}
			if pod.Spec.SchedulerName != "" && pod.Spec.SchedulerName != "kubedelta-scheduler" {
				return
			}
			clone := pod.DeepCopy()
			if clone.Annotations == nil {
				clone.Annotations = map[string]string{}
			}
			clone.Annotations[AnnotationTaskID] = TaskIDForPod(pod)
			clone.Annotations["kubedelta.io/audit-at"] = fmt.Sprintf("%d", time.Now().Unix())
			_, _ = client.CoreV1().Pods(pod.Namespace).Update(ctx, clone, metav1.UpdateOptions{})
		},
	})
	factory.Start(ctx.Done())
	<-ctx.Done()
}
