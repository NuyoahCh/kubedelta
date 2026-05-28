package extender

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	schedextender "k8s.io/kube-scheduler/extender/v1"
)

const (
	AnnotationNodePool = "kubedelta.io/nodepool"
	LabelNodePool      = "nodepool.kubedelta.io/name"
	LabelTolerance     = "kubedelta.io/tolerance"
	AnnotationTaskID   = "kubedelta.io/task-id"
)

// Server 实现 kube-scheduler HTTP Extender，映射 pelen/celan 流程中的检查点。
type Server struct {
	Mux *http.ServeMux
}

func New() *Server {
	s := &Server{Mux: http.NewServeMux()}
	s.Mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	s.Mux.HandleFunc("/filter", s.filter)
	s.Mux.HandleFunc("/prioritize", s.prioritize)
	return s
}

func (s *Server) filter(w http.ResponseWriter, r *http.Request) {
	var args schedextender.ExtenderArgs
	if err := json.NewDecoder(r.Body).Decode(&args); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	pod := args.Pod
	var failed map[string]string
	if msg := clusterCapacityCheck(nodeItems(args), pod); msg != "" {
		failed = failAll(nodeItems(args), msg)
	} else {
		failed = map[string]string{}
		for i := range nodeItems(args) {
			n := nodeItems(args)[i]
			if msg := perNodeFilter(n, pod); msg != "" {
				failed[n.Name] = msg
			}
		}
	}
	writeJSON(w, schedextender.ExtenderFilterResult{FailedNodes: failed, Nodes: args.Nodes})
}

func (s *Server) prioritize(w http.ResponseWriter, r *http.Request) {
	var args schedextender.ExtenderArgs
	if err := json.NewDecoder(r.Body).Decode(&args); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	pod := args.Pod
	var list schedextender.HostPriorityList
	for _, n := range nodeItems(args) {
		score := int64(0)
		if len(pod.Spec.Tolerations) > 0 && n.Labels[LabelTolerance] == "true" {
			score = 50
		}
		list = append(list, schedextender.HostPriority{Host: n.Name, Score: score})
	}
	writeJSON(w, list)
}

func nodeItems(args schedextender.ExtenderArgs) []corev1.Node {
	if args.Nodes != nil {
		return args.Nodes.Items
	}
	return nil
}

func clusterCapacityCheck(nodes []corev1.Node, pod *corev1.Pod) string {
	req := sumPodRequests(pod)
	var cpu, mem resource.Quantity
	for _, n := range nodes {
		cpu.Add(*n.Status.Allocatable.Cpu())
		mem.Add(*n.Status.Allocatable.Memory())
	}
	if cpu.Cmp(req.cpu) < 0 || mem.Cmp(req.mem) < 0 {
		return fmt.Sprintf("cluster capacity insufficient (need cpu=%s mem=%s)", req.cpu.String(), req.mem.String())
	}
	return ""
}

func perNodeFilter(node corev1.Node, pod *corev1.Pod) string {
	for _, c := range node.Status.Conditions {
		if c.Type == corev1.NodeReady && c.Status != corev1.ConditionTrue {
			return "kubedelta: node not ready"
		}
	}
	if want, ok := pod.Annotations[AnnotationNodePool]; ok && want != "" {
		if node.Labels[LabelNodePool] != want {
			return "kubedelta: nodepool mismatch"
		}
	}
	return ""
}

type podReq struct {
	cpu, mem resource.Quantity
}

func sumPodRequests(pod *corev1.Pod) podReq {
	cpu := resource.NewQuantity(0, resource.DecimalSI)
	mem := resource.NewQuantity(0, resource.BinarySI)
	for _, c := range pod.Spec.Containers {
		if q, ok := c.Resources.Requests[corev1.ResourceCPU]; ok {
			cpu.Add(q)
		}
		if q, ok := c.Resources.Requests[corev1.ResourceMemory]; ok {
			mem.Add(q)
		}
	}
	return podReq{cpu: *cpu, mem: *mem}
}

func failAll(nodes []corev1.Node, msg string) map[string]string {
	out := make(map[string]string, len(nodes))
	for _, n := range nodes {
		out[n.Name] = msg
	}
	return out
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(v)
}

// TaskIDForPod 生成调度留痕 ID（流程图 step 4）。
func TaskIDForPod(pod *corev1.Pod) string {
	return fmt.Sprintf("task-%s-%s", pod.Namespace, strings.TrimSpace(pod.Name))
}
