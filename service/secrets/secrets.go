// Copyright 2022 Aspect Build Systems, Inc. All rights reserved.
//
// Original authors: Thulio Ferraz Assis (thulio@aspect.dev)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package secrets

import (
	"fmt"
	"io"
	"io/fs"
	"os"
)

// Secrets is a singleton that manages secrets in a filesystem.
var secrets internalSecrets

// SetSecretsDir sets the internal secrets filesystem to the tree of files
// rooted at the given dir.
func SetSecretsDir(dir string) {
	secrets.setSecretsDir(dir)
}

// Get returns the value of the given secret. It must match one of the requested
// secrets in the talkie_service rule.
func Get(secret string) (string, error) {
	return secrets.get(secret)
}

type internalSecrets struct {
	secretsDir fs.FS
}

func (s *internalSecrets) setSecretsDir(dir string) {
	s.secretsDir = os.DirFS(dir)
}

func (s *internalSecrets) get(secret string) (string, error) {
	if s.secretsDir == nil {
		return "", fmt.Errorf("failed to get secret %q: secrets filesystem not initialized", secret)
	}
	secretFile, err := s.secretsDir.Open(secret)
	if err != nil {
		return "", fmt.Errorf("failed to get secret %q: %w", secret, err)
	}
	defer secretFile.Close()
	redisURL, err := io.ReadAll(secretFile)
	if err != nil {
		return "", fmt.Errorf("failed to get secret %q: %w", secret, err)
	}
	return string(redisURL), nil
}
