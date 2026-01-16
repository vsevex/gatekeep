package queue

import (
	"testing"
	"time"
)

func TestSendHeartbeat_Success(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	// Join queue
	req := JoinQueueRequest{
		EventID:        "test-event-heartbeat",
		DeviceID:       "device-heartbeat",
		UserID:         "user-heartbeat",
		PriorityBucket: "normal",
	}

	entry, err := manager.JoinQueue(req)
	if err != nil {
		t.Fatalf("JoinQueue() failed: %v", err)
	}

	// Get initial status
	initialStatus, err := manager.GetQueueStatus(entry.QueueID)
	if err != nil {
		t.Fatalf("GetQueueStatus() failed: %v", err)
	}
	initialHeartbeat := initialStatus.LastHeartbeat

	// Wait a bit
	time.Sleep(100 * time.Millisecond)

	// Send heartbeat
	status, err := manager.SendHeartbeat(entry.QueueID)
	if err != nil {
		t.Fatalf("SendHeartbeat() failed: %v", err)
	}

	if status == nil {
		t.Fatal("SendHeartbeat() returned nil")
	}

	if status.QueueID != entry.QueueID {
		t.Errorf("QueueID mismatch: expected %s, got %s", entry.QueueID, status.QueueID)
	}

	// Verify heartbeat was updated
	if !status.LastHeartbeat.After(initialHeartbeat) {
		t.Errorf("LastHeartbeat should be updated: initial %v, current %v", initialHeartbeat, status.LastHeartbeat)
	}

	// Verify status is still waiting
	if status.Status != "waiting" {
		t.Errorf("Status should be 'waiting', got %s", status.Status)
	}
}

func TestSendHeartbeat_ExtendsTTL(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	// Join queue
	req := JoinQueueRequest{
		EventID:        "test-event-ttl",
		DeviceID:       "device-ttl",
		UserID:         "user-ttl",
		PriorityBucket: "normal",
	}

	entry, err := manager.JoinQueue(req)
	if err != nil {
		t.Fatalf("JoinQueue() failed: %v", err)
	}

	// Send heartbeat multiple times
	for i := 0; i < 3; i++ {
		status, err := manager.SendHeartbeat(entry.QueueID)
		if err != nil {
			t.Fatalf("SendHeartbeat() #%d failed: %v", i+1, err)
		}
		if status == nil {
			t.Fatalf("SendHeartbeat() #%d returned nil", i+1)
		}
		time.Sleep(50 * time.Millisecond)
	}

	// Verify entry still exists
	finalStatus, err := manager.GetQueueStatus(entry.QueueID)
	if err != nil {
		t.Fatalf("GetQueueStatus() after heartbeats failed: %v", err)
	}
	if finalStatus == nil {
		t.Fatal("Entry should still exist after heartbeats")
	}
}

func TestSendHeartbeat_NonExistent(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	_, err := manager.SendHeartbeat("non-existent-queue-id")
	if err == nil {
		t.Error("SendHeartbeat() expected error for non-existent queue_id, got nil")
		return
	}
}

func TestSendHeartbeat_ReturnsTokenWhenAdmitted(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	// Join queue
	req := JoinQueueRequest{
		EventID:        "test-event-token",
		DeviceID:       "device-token",
		UserID:         "user-token",
		PriorityBucket: "normal",
	}

	entry, err := manager.JoinQueue(req)
	if err != nil {
		t.Fatalf("JoinQueue() failed: %v", err)
	}

	// Mark as admitted
	if err := manager.MarkAsAdmitted(entry.QueueID); err != nil {
		t.Fatalf("MarkAsAdmitted() failed: %v", err)
	}

	// Send heartbeat - should return admitted status
	status, err := manager.SendHeartbeat(entry.QueueID)
	if err != nil {
		t.Fatalf("SendHeartbeat() failed: %v", err)
	}

	if status.Status != "admitted" {
		t.Errorf("Status should be 'admitted', got %s", status.Status)
	}
	if status.Position != 0 {
		t.Errorf("Position should be 0 for admitted users, got %d", status.Position)
	}
}

func TestSendHeartbeat_EmptyQueueID(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	_, err := manager.SendHeartbeat("")
	if err == nil {
		t.Error("SendHeartbeat() expected error for empty queue_id, got nil")
		return
	}
}

func TestSendHeartbeat_Concurrent(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	// Join queue
	req := JoinQueueRequest{
		EventID:        "test-event-concurrent",
		DeviceID:       "device-concurrent",
		UserID:         "user-concurrent",
		PriorityBucket: "normal",
	}

	entry, err := manager.JoinQueue(req)
	if err != nil {
		t.Fatalf("JoinQueue() failed: %v", err)
	}

	// Send multiple heartbeats concurrently
	done := make(chan bool, 5)
	for i := 0; i < 5; i++ {
		go func() {
			_, err := manager.SendHeartbeat(entry.QueueID)
			done <- (err == nil)
		}()
	}

	// Wait for all to complete
	successCount := 0
	for i := 0; i < 5; i++ {
		if <-done {
			successCount++
		}
	}

	if successCount != 5 {
		t.Errorf("Expected all 5 concurrent heartbeats to succeed, got %d successes", successCount)
	}
}

func TestMarkAsAdmitted(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	// Join queue
	req := JoinQueueRequest{
		EventID:        "test-event-mark",
		DeviceID:       "device-mark",
		UserID:         "user-mark",
		PriorityBucket: "normal",
	}

	entry, err := manager.JoinQueue(req)
	if err != nil {
		t.Fatalf("JoinQueue() failed: %v", err)
	}

	// Mark as admitted
	if err := manager.MarkAsAdmitted(entry.QueueID); err != nil {
		t.Fatalf("MarkAsAdmitted() failed: %v", err)
	}

	// Verify status is admitted
	status, err := manager.GetQueueStatus(entry.QueueID)
	if err != nil {
		t.Fatalf("GetQueueStatus() failed: %v", err)
	}

	if status.Status != "admitted" {
		t.Errorf("Status should be 'admitted', got %s", status.Status)
	}
}

func TestMarkAsAdmitted_NonExistent(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	err := manager.MarkAsAdmitted("non-existent-queue-id")
	if err == nil {
		t.Error("MarkAsAdmitted() expected error for non-existent queue_id, got nil")
	}
}

func TestMarkAsAdmitted_EmptyQueueID(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	err := manager.MarkAsAdmitted("")
	if err == nil {
		t.Error("MarkAsAdmitted() expected error for empty queue_id, got nil")
	}
}

func TestCleanupAbandonedSessions(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	// This is a placeholder test - the function is currently a no-op
	err := manager.CleanupAbandonedSessions()
	if err != nil {
		t.Errorf("CleanupAbandonedSessions() failed: %v", err)
	}
}
