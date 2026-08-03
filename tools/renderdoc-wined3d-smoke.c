#define COBJMACROS

#include <windows.h>
#include <d3d11.h>
#include <stdbool.h>
#include <stdio.h>

#include "renderdoc_app.h"

typedef int (RENDERDOC_CC *pRENDERDOC_GetAPI)(
    RENDERDOC_Version version,
    void **out_api_pointers);

int main(void)
{
    WNDCLASSA window_class = {0};
    HWND window;
    IDXGISwapChain *swapchain = NULL;
    ID3D11Device *device = NULL;
    ID3D11DeviceContext *context = NULL;
    ID3D11Texture2D *target = NULL;
    ID3D11RenderTargetView *rtv = NULL;
    RENDERDOC_API_1_6_0 *rdoc = NULL;
    D3D_FEATURE_LEVEL feature_level;
    HRESULT hr;
    HMODULE module;
    pRENDERDOC_GetAPI get_api;

    window_class.lpfnWndProc = DefWindowProcA;
    window_class.hInstance = GetModuleHandleA(NULL);
    window_class.lpszClassName = "RenderDocWineD3DSmoke";
    if (!RegisterClassA(&window_class))
        return 1;
    window = CreateWindowA(window_class.lpszClassName, "RenderDoc WineD3D Smoke",
                           WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,
                           128, 128, NULL, NULL, window_class.hInstance, NULL);
    if (!window)
        return 2;

    {
        DXGI_SWAP_CHAIN_DESC desc = {0};
        desc.BufferDesc.Width = 64;
        desc.BufferDesc.Height = 64;
        desc.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
        desc.SampleDesc.Count = 1;
        desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
        desc.BufferCount = 2;
        desc.OutputWindow = window;
        desc.Windowed = TRUE;
        desc.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;
        hr = D3D11CreateDeviceAndSwapChain(
            NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, 0, NULL, 0,
            D3D11_SDK_VERSION, &desc, &swapchain, &device, &feature_level,
            &context);
    }
    if (FAILED(hr)) {
        fprintf(stderr, "D3D11CreateDeviceAndSwapChain failed: 0x%08lx\n",
                (unsigned long)hr);
        return 3;
    }

    module = GetModuleHandleA("renderdoc.dll");
    if (!module) {
        fprintf(stderr, "renderdoc.dll is not injected\n");
        return 2;
    }
    get_api = (pRENDERDOC_GetAPI)GetProcAddress(module, "RENDERDOC_GetAPI");
    if (!get_api ||
        !get_api(eRENDERDOC_API_Version_1_6_0, (void **)&rdoc) ||
        !rdoc) {
        fprintf(stderr, "RENDERDOC_GetAPI failed\n");
        return 3;
    }

    hr = IDXGISwapChain_GetBuffer(
        swapchain, 0, &IID_ID3D11Texture2D, (void **)&target);
    if (FAILED(hr))
        return 4;
    hr = ID3D11Device_CreateRenderTargetView(
        device, (ID3D11Resource *)target, NULL, &rtv);
    if (FAILED(hr))
        return 5;

    rdoc->SetCaptureFilePathTemplate(
        "Z:\\Users\\yabai\\myproject\\WineProject\\er-dxmt-build\\tools\\"
        "renderdoc-wined3d-smoke");
    rdoc->StartFrameCapture((RENDERDOC_DevicePointer)device,
                            (RENDERDOC_WindowHandle)window);
    for (unsigned frame = 0; frame < 3; ++frame) {
        const float color[4] = {
            0.25f + 0.1f * frame,
            0.5f,
            0.75f,
            1.0f,
        };
        ID3D11DeviceContext_ClearRenderTargetView(context, rtv, color);
        IDXGISwapChain_Present(swapchain, 0, 0);
        if (frame == 0 &&
            !rdoc->EndFrameCapture((RENDERDOC_DevicePointer)device,
                                   (RENDERDOC_WindowHandle)window)) {
            fprintf(stderr, "EndFrameCapture failed\n");
            return 6;
        }
    }

    printf("RenderDoc WineD3D capture completed\n");

    ID3D11RenderTargetView_Release(rtv);
    ID3D11Texture2D_Release(target);
    IDXGISwapChain_Release(swapchain);
    ID3D11DeviceContext_Release(context);
    ID3D11Device_Release(device);
    return 0;
}
