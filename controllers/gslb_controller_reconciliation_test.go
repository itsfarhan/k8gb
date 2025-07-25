package controllers

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

import (
	"context"
	"errors"

	"github.com/k8gb-io/k8gb/controllers/resolver"

	"github.com/k8gb-io/k8gb/api/v1beta1"
	"github.com/k8gb-io/k8gb/controllers/mocks"
	"github.com/k8gb-io/k8gb/controllers/tracing"
	"github.com/stretchr/testify/assert"
	"go.uber.org/mock/gomock"
	netv1 "k8s.io/api/networking/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/apimachinery/pkg/types"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
	clientgoscheme "k8s.io/client-go/kubernetes/scheme"
	controllerruntime "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"

	"testing"
)

func TestReconciliation(t *testing.T) {
	const (
		reqName      = "test"
		reqNamespace = "default"
	)
	skipTest := errors.New("this indicates that test successfully passed but skipping reconciliation")
	config := &resolver.Config{
		ReconcileRequeueSeconds: 0,
	}
	var tests = []struct {
		name          string
		setup         func(*gomock.Controller) *GslbReconciler
		expectedError bool
	}{
		{
			name:          "GSLB creates dependent ingress without annotations",
			expectedError: false,
			setup: func(ctrl *gomock.Controller) *GslbReconciler {

				found := &v1beta1.Gslb{
					ObjectMeta: metav1.ObjectMeta{
						Name:        reqName,
						Namespace:   reqNamespace,
						Annotations: map[string]string{"app": reqName},
					},
					Spec: v1beta1.GslbSpec{
						Strategy: v1beta1.Strategy{
							DNSTtlSeconds: 5,
							Type:          "roundRobin",
						},
					},
				}

				cleanup, tracer := tracing.SetupTracing(context.Background(), tracing.Settings{}, log)
				defer cleanup()
				cl := mocks.NewMockClient(ctrl)
				resolver := mocks.NewMockGslbResolver(ctrl)
				// reading GSLB from request
				cl.EXPECT().
					Get(gomock.Any(), gomock.Any(), gomock.Any(), gomock.Any()).
					DoAndReturn(func(_ context.Context, _ client.ObjectKey, obj client.Object, _ ...client.GetOption) error {
						gslb := obj.(*v1beta1.Gslb)
						*gslb = *found
						return nil
					}).
					Times(1)
				// resolve GSLB spec
				resolver.EXPECT().ResolveGslbSpec(gomock.Any(), gomock.Any(), gomock.Any()).Return(nil).Times(1)
				// Create ingress from GLSB, check if ingress exists - doesnt exists
				cl.EXPECT().Get(gomock.Any(), gomock.Any(), gomock.Any(), gomock.Any()).
					Return(apierrors.NewNotFound(schema.GroupResource{Group: "networking.k8s.io", Resource: "ingresses"}, "found")).Times(1)

				// Crete ingress and check annotation, skip rest of the test
				cl.EXPECT().
					Create(gomock.Any(), gomock.Any(), gomock.Any()).
					DoAndReturn(func(_ context.Context, obj client.Object, _ ...client.CreateOption) error {
						ingress := obj.(*netv1.Ingress)
						assert.Equal(t, 0, len(ingress.Annotations))
						return skipTest
					}).Times(1)

				reconciler := &GslbReconciler{
					Config:   config,
					Tracer:   tracer,
					Client:   cl,
					Resolver: resolver,
				}
				return reconciler
			},
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {

			// arrange
			ctrl := gomock.NewController(t)
			defer ctrl.Finish()
			reconciler := test.setup(ctrl)
			scheme := runtime.NewScheme()
			utilruntime.Must(clientgoscheme.AddToScheme(scheme))
			utilruntime.Must(netv1.AddToScheme(scheme))
			utilruntime.Must(v1beta1.AddToScheme(scheme))
			reconciler.Scheme = scheme

			// act
			_, err := reconciler.Reconcile(context.TODO(), controllerruntime.Request{
				NamespacedName: types.NamespacedName{
					Name:      reqName,
					Namespace: reqNamespace,
				},
			})

			// assert
			if test.expectedError {
				assert.Error(t, err)
				return
			}

			if errors.Is(err, skipTest) {
				return
			}
			assert.Nil(t, err)
		})
	}
}
