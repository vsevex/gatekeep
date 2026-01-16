package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// QueueLength tracks the current queue length per event
	QueueLength = promauto.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "gatekeep_queue_length",
			Help: "Current number of users in the queue",
		},
		[]string{"event_id"},
	)

	// WaitTime tracks the average wait time per event
	WaitTime = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "gatekeep_wait_time_seconds",
			Help:    "Time users wait in the queue",
			Buckets: prometheus.ExponentialBuckets(1, 2, 10), // 1s to ~512s
		},
		[]string{"event_id"},
	)

	// ReleaseRate tracks the release rate per event
	ReleaseRate = promauto.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "gatekeep_release_rate",
			Help: "Current release rate (users per second)",
		},
		[]string{"event_id"},
	)

	// AdmissionCount tracks the total number of admissions per event
	AdmissionCount = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "gatekeep_admissions_total",
			Help: "Total number of users admitted",
		},
		[]string{"event_id"},
	)

	// APIRequestDuration tracks API request duration
	APIRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "gatekeep_api_request_duration_seconds",
			Help:    "Duration of API requests",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "endpoint", "status"},
	)

	// RedisOperationDuration tracks Redis operation duration
	RedisOperationDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "gatekeep_redis_operation_duration_seconds",
			Help:    "Duration of Redis operations",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"operation"},
	)

	// QueueJoins tracks queue join operations
	QueueJoins = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "gatekeep_queue_joins_total",
			Help: "Total number of queue joins",
		},
		[]string{"event_id", "priority"},
	)

	// QueueHeartbeats tracks heartbeat operations
	QueueHeartbeats = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "gatekeep_queue_heartbeats_total",
			Help: "Total number of heartbeats",
		},
		[]string{"event_id"},
	)
)
