package main

import (
	"bytes"
	"context"
	"fmt"
	"os/exec"

	"github.com/coreos/go-systemd/v22/daemon"
)

func xochitl(ctx context.Context) (kill func() error, result chan error) {
	result = make(chan error, 1)

	if ok, err := daemon.SdNotify(false, daemon.SdNotifyReady); ok {
		kill = func() error {
			_, err := daemon.SdNotify(false, daemon.SdNotifyStopping)

			return err
		}

		return kill, result
	} else if err != nil {
		result <- fmt.Errorf("notifying systemd: %w", err)
		close(result)

		return nil, result
	}

	// no systemd - start xochitl ourselves
	var stdErr bytes.Buffer

	cmd := exec.CommandContext(ctx, "xochitl", "--system")
	cmd.Stderr = &stdErr

	err := cmd.Start()
	if err != nil {
		result <- fmt.Errorf("starting mount: %w", err)
		close(result)

		return nil, result
	}

	go func() {
		err := cmd.Wait()
		if err != nil {
			exitErr, ok := err.(*exec.ExitError) //nolint:errorlint
			if ok {
				err = fmt.Errorf("error code %d: %s", exitErr.ExitCode(), stdErr.String())
			}
		}

		result <- err
		close(result)
	}()

	return cmd.Process.Kill, result
}
