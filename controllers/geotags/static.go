package geotags

/*
Copyright 2021-2025 The k8gb Contributors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Generated by GoLic, for more details see: https://github.com/AbsaOSS/golic
*/

import "github.com/k8gb-io/k8gb/controllers/resolver"

type Static struct {
	config *resolver.Config
}

func NewStatic(config *resolver.Config) *Static {
	return &Static{
		config: config,
	}
}

func (s *Static) GetExternalClusterNSNamesByHostname(host string) (map[string]string, error) {
	z := getZone(s.config, host)
	if z != nil {
		return z.ExtClusterNSNames, nil
	}
	return map[string]string{}, nil
}
