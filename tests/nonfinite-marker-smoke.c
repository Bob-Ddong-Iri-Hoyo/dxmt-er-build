#define COBJMACROS
#include <windows.h>
#include <d3d11.h>
#include <d3dcompiler.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static int failed(const char *step, HRESULT hr) {
  fprintf(stderr, "%s failed: 0x%08lx\n", step, (unsigned long)hr);
  return 1;
}

static HRESULT compile_shader(const char *source, const char *entry,
                              const char *target, ID3DBlob **blob) {
  ID3DBlob *errors = NULL;
  HRESULT hr = D3DCompile(source, strlen(source), "nonfinite-marker-smoke.hlsl",
                          NULL, NULL, entry, target, D3DCOMPILE_OPTIMIZATION_LEVEL3,
                          0, blob, &errors);
  if (errors) {
    fwrite(ID3D10Blob_GetBufferPointer(errors), 1,
           ID3D10Blob_GetBufferSize(errors), stderr);
    ID3D10Blob_Release(errors);
  }
  return hr;
}

int main(void) {
  static const char shader_source[] =
    "cbuffer Diagnostic : register(b0) { float trigger; float3 padding; };"
    "struct VSOut { float4 position : SV_Position; };"
    "VSOut vs_main(uint id : SV_VertexID) {"
    "  float2 p[3] = { float2(-1,-1), float2(-1,3), float2(3,-1) };"
    "  VSOut o; o.position = float4(p[id], 0, 1); return o;"
    "}"
    "float4 ps_main(VSOut input) : SV_Target0 {"
    "  float nonfinite = trigger / trigger;"
    "  return float4(nonfinite, 0, 0, 1);"
    "}";

  HRESULT hr;
  D3D_FEATURE_LEVEL feature_level;
  ID3D11Device *device = NULL;
  ID3D11DeviceContext *context = NULL;
  ID3DBlob *vs_blob = NULL;
  ID3DBlob *ps_blob = NULL;
  ID3D11VertexShader *vs = NULL;
  ID3D11PixelShader *ps = NULL;
  ID3D11Buffer *constant_buffer = NULL;
  ID3D11Texture2D *target = NULL;
  ID3D11Texture2D *staging = NULL;
  ID3D11RenderTargetView *rtv = NULL;
  D3D11_MAPPED_SUBRESOURCE mapped;
  int result = 1;

  hr = D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, 0, NULL, 0,
                         D3D11_SDK_VERSION, &device, &feature_level, &context);
  if (FAILED(hr))
    return failed("D3D11CreateDevice", hr);

  hr = compile_shader(shader_source, "vs_main", "vs_5_0", &vs_blob);
  if (FAILED(hr)) {
    failed("D3DCompile(vs)", hr);
    goto cleanup;
  }
  hr = compile_shader(shader_source, "ps_main", "ps_5_0", &ps_blob);
  if (FAILED(hr)) {
    failed("D3DCompile(ps)", hr);
    goto cleanup;
  }

  hr = ID3D11Device_CreateVertexShader(
    device, ID3D10Blob_GetBufferPointer(vs_blob),
    ID3D10Blob_GetBufferSize(vs_blob), NULL, &vs);
  if (FAILED(hr)) {
    failed("CreateVertexShader", hr);
    goto cleanup;
  }
  hr = ID3D11Device_CreatePixelShader(
    device, ID3D10Blob_GetBufferPointer(ps_blob),
    ID3D10Blob_GetBufferSize(ps_blob), NULL, &ps);
  if (FAILED(hr)) {
    failed("CreatePixelShader", hr);
    goto cleanup;
  }

  {
    const float zeros[4] = {0, 0, 0, 0};
    D3D11_BUFFER_DESC desc = {0};
    D3D11_SUBRESOURCE_DATA initial = {0};
    desc.ByteWidth = sizeof(zeros);
    desc.Usage = D3D11_USAGE_DEFAULT;
    desc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
    initial.pSysMem = zeros;
    hr = ID3D11Device_CreateBuffer(device, &desc, &initial, &constant_buffer);
    if (FAILED(hr)) {
      failed("CreateBuffer", hr);
      goto cleanup;
    }
  }

  {
    D3D11_TEXTURE2D_DESC desc = {0};
    desc.Width = 1;
    desc.Height = 1;
    desc.MipLevels = 1;
    desc.ArraySize = 1;
    desc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    desc.SampleDesc.Count = 1;
    desc.Usage = D3D11_USAGE_DEFAULT;
    desc.BindFlags = D3D11_BIND_RENDER_TARGET;
    hr = ID3D11Device_CreateTexture2D(device, &desc, NULL, &target);
    if (FAILED(hr)) {
      failed("CreateTexture2D(target)", hr);
      goto cleanup;
    }
    hr = ID3D11Device_CreateRenderTargetView(device, (ID3D11Resource *)target,
                                             NULL, &rtv);
    if (FAILED(hr)) {
      failed("CreateRenderTargetView", hr);
      goto cleanup;
    }
    desc.Usage = D3D11_USAGE_STAGING;
    desc.BindFlags = 0;
    desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    hr = ID3D11Device_CreateTexture2D(device, &desc, NULL, &staging);
    if (FAILED(hr)) {
      failed("CreateTexture2D(staging)", hr);
      goto cleanup;
    }
  }

  {
    const float clear[4] = {0, 0, 0, 0};
    D3D11_VIEWPORT viewport = {0, 0, 1, 1, 0, 1};
    ID3D11DeviceContext_ClearRenderTargetView(context, rtv, clear);
    ID3D11DeviceContext_OMSetRenderTargets(context, 1, &rtv, NULL);
    ID3D11DeviceContext_RSSetViewports(context, 1, &viewport);
    ID3D11DeviceContext_IASetPrimitiveTopology(
      context, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    ID3D11DeviceContext_VSSetShader(context, vs, NULL, 0);
    ID3D11DeviceContext_PSSetShader(context, ps, NULL, 0);
    ID3D11DeviceContext_PSSetConstantBuffers(context, 0, 1, &constant_buffer);
    ID3D11DeviceContext_Draw(context, 3, 0);
    ID3D11DeviceContext_CopyResource(context, (ID3D11Resource *)staging,
                                     (ID3D11Resource *)target);
    ID3D11DeviceContext_Flush(context);
  }

  hr = ID3D11DeviceContext_Map(context, (ID3D11Resource *)staging, 0,
                               D3D11_MAP_READ, 0, &mapped);
  if (FAILED(hr)) {
    failed("Map(staging)", hr);
    goto cleanup;
  }
  {
    const uint8_t *pixel = (const uint8_t *)mapped.pData;
    printf("pixel=%u,%u,%u,%u expected=255,255,255,255\n",
           pixel[0], pixel[1], pixel[2], pixel[3]);
    result = (pixel[0] == 255 && pixel[1] == 255 &&
              pixel[2] == 255 && pixel[3] == 255) ? 0 : 2;
  }
  ID3D11DeviceContext_Unmap(context, (ID3D11Resource *)staging, 0);

cleanup:
  if (rtv) ID3D11RenderTargetView_Release(rtv);
  if (staging) ID3D11Texture2D_Release(staging);
  if (target) ID3D11Texture2D_Release(target);
  if (constant_buffer) ID3D11Buffer_Release(constant_buffer);
  if (ps) ID3D11PixelShader_Release(ps);
  if (vs) ID3D11VertexShader_Release(vs);
  if (ps_blob) ID3D10Blob_Release(ps_blob);
  if (vs_blob) ID3D10Blob_Release(vs_blob);
  if (context) ID3D11DeviceContext_Release(context);
  if (device) ID3D11Device_Release(device);
  return result;
}
