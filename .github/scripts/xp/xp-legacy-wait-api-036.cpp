#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct Context {
  HANDLE watched;
  HANDLE callbackEntered;
  HANDLE callbackProceed;
  HANDLE callbackExited;
  HANDLE registration;
  volatile LONG callbacks;
  volatile LONG callbackActive;
  volatile LONG unregisterCalls;
};

static void CALLBACK OnWait(void* arg, BOOLEAN timedOut) {
  Context* c = static_cast<Context*>(arg);
  InterlockedIncrement(&c->callbackActive);
  InterlockedIncrement(&c->callbacks);
  SetEvent(c->callbackEntered);
  WaitForSingleObject(c->callbackProceed, INFINITE);
  InterlockedDecrement(&c->callbackActive);
  SetEvent(c->callbackExited);
}

static bool Check(bool ok, const char* name) {
  printf("%s=%s\n", name, ok ? "PASS" : "FAIL");
  return ok;
}

int main(int argc, char** argv) {
  if (argc != 2) return 2;
  const bool presignaled = strcmp(argv[1], "presignaled") == 0;
  const bool cancelPending = strcmp(argv[1], "cancel-pending") == 0;
  const bool cancelRunning = strcmp(argv[1], "cancel-running") == 0;
  const bool complete = strcmp(argv[1], "completion") == 0;
  if (!presignaled && !cancelPending && !cancelRunning && !complete) return 2;
  Context c = {};
  c.watched = CreateEventA(NULL, TRUE, FALSE, NULL);
  c.callbackEntered = CreateEventA(NULL, TRUE, FALSE, NULL);
  c.callbackProceed = CreateEventA(NULL, TRUE, FALSE, NULL);
  c.callbackExited = CreateEventA(NULL, TRUE, FALSE, NULL);
  if (!c.watched || !c.callbackEntered || !c.callbackProceed || !c.callbackExited) return 3;
  if (presignaled) SetEvent(c.watched);
  if (!RegisterWaitForSingleObject(&c.registration, c.watched, OnWait, &c,
                                   INFINITE, WT_EXECUTEONLYONCE)) return 4;
  if (complete || cancelRunning) SetEvent(c.watched);
  bool ok = true;
  if (cancelPending) {
    BOOL rc = UnregisterWaitEx(c.registration, INVALID_HANDLE_VALUE);
    InterlockedIncrement(&c.unregisterCalls);
    ok &= Check(rc != 0, "pending_unregister");
    SetEvent(c.watched);
    ok &= Check(WaitForSingleObject(c.callbackEntered, 100) == WAIT_TIMEOUT,
                "pending_callback_not_delivered");
  } else {
    ok &= Check(WaitForSingleObject(c.callbackEntered, 5000) == WAIT_OBJECT_0,
                "callback_entered");
    if (complete || presignaled) {
      SetLastError(ERROR_SUCCESS);
      BOOL rc = UnregisterWaitEx(c.registration, NULL);
      DWORD error = GetLastError();
      InterlockedIncrement(&c.unregisterCalls);
      printf("nonblocking_unregister_rc=%lu error=%lu\n", (unsigned long)rc,
             (unsigned long)error);
      ok &= Check(rc || error == ERROR_IO_PENDING, "nonblocking_unregister_accepted");
      ok &= Check(InterlockedCompareExchange(&c.callbackActive, 0, 0) == 1,
                  "callback_still_active_after_unregister");
      SetEvent(c.callbackProceed);
    } else {
      // A separate cancellation thread is required: blocking unregister must
      // not run inside the callback or under the watcher's mutex.
      HANDLE thread = CreateThread(NULL, 0, [](void* arg)->DWORD {
        Context* c = static_cast<Context*>(arg);
        BOOL rc = UnregisterWaitEx(c->registration, INVALID_HANDLE_VALUE);
        InterlockedIncrement(&c->unregisterCalls);
        return rc ? 0 : GetLastError();
      }, &c, 0, NULL);
      if (!thread) return 5;
      ok &= Check(WaitForSingleObject(thread, 100) == WAIT_TIMEOUT,
                  "running_unregister_waits");
      SetEvent(c.callbackProceed);
      ok &= Check(WaitForSingleObject(thread, 5000) == WAIT_OBJECT_0,
                  "running_unregister_completed");
      DWORD exitCode = 0;
      GetExitCodeThread(thread, &exitCode);
      ok &= Check(exitCode == 0, "running_unregister_success");
      CloseHandle(thread);
    }
    ok &= Check(WaitForSingleObject(c.callbackExited, 5000) == WAIT_OBJECT_0,
                "callback_body_exit_observed");
  }
  ok &= Check(c.unregisterCalls == 1, "single_unregister_owner");
  printf("callbacks=%ld active=%ld unregisters=%ld\n",
         c.callbacks, c.callbackActive, c.unregisterCalls);
  CloseHandle(c.callbackExited);
  CloseHandle(c.callbackProceed);
  CloseHandle(c.callbackEntered);
  CloseHandle(c.watched);
  // Context is stack-owned for the entire test-process lifetime. This test
  // DOES NOT prove safe production reclamation after nonblocking unregister.
  return ok ? 0 : 1;
}
