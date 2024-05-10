// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

// A minimal UI for simple testing via a UI without Vault
package jwtauth

import (
	"context"
	"os"

	"github.com/openbao/openbao/sdk/framework"
	"github.com/openbao/openbao/sdk/logical"
)

func pathUI(b *jwtAuthBackend) *framework.Path {
	return &framework.Path{
		Pattern: `ui$`,

		DisplayAttrs: &framework.DisplayAttributes{
			OperationPrefix: operationPrefixJWT,
			OperationVerb:   "ui",
		},

		Callbacks: map[logical.Operation]framework.OperationFunc{
			logical.ReadOperation: b.pathUI,
		},
	}
}

func (b *jwtAuthBackend) pathUI(ctx context.Context, req *logical.Request, d *framework.FieldData) (*logical.Response, error) {
	data, err := os.ReadFile("test_ui.html")
	if err != nil {
		panic(err)
	}

	resp := &logical.Response{
		Data: map[string]interface{}{
			logical.HTTPStatusCode:  200,
			logical.HTTPRawBody:     string(data),
			logical.HTTPContentType: "text/html",
		},
	}

	return resp, nil
}
