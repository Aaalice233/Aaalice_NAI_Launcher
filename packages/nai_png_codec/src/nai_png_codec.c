#include <stdint.h>
#include <stdlib.h>
#include "spng.h"

#if defined(_WIN32)
#define NAI_EXPORT __declspec(dllexport)
#else
#define NAI_EXPORT __attribute__((visibility("default")))
#endif

/* The caller owns input; output must be released by this library's allocator. */
NAI_EXPORT void nai_png_free(void *memory) { free(memory); }

NAI_EXPORT const char *nai_png_error(int code) {
    if (code == -1001) return "Decoded PNG exceeds the 512 MiB memory budget";
    if (code == -1002) return "Invalid PNG codec arguments";
    return spng_strerror(-code);
}

NAI_EXPORT int nai_png_encode_rgba(const uint8_t *pixels, size_t pixel_size,
                                   uint32_t width, uint32_t height,
                                   void **output, size_t *output_size) {
    if (!pixels || !output || !output_size || !width || !height ||
        (uint64_t)width * height * 4 != pixel_size) return -1002;
    *output = NULL;
    *output_size = 0;
    spng_ctx *encoder = spng_ctx_new(SPNG_CTX_ENCODER);
    if (!encoder) return -SPNG_EMEM;
    int result;
    struct spng_ihdr header = {0};
    header.width = width;
    header.height = height;
    header.bit_depth = 8;
    header.color_type = SPNG_COLOR_TYPE_TRUECOLOR_ALPHA;
#define ENCODE_CHECK(call) do { result = (call); if (result) { result = -result; goto encoded; } } while (0)
    ENCODE_CHECK(spng_set_option(encoder, SPNG_ENCODE_TO_BUFFER, 1));
    ENCODE_CHECK(spng_set_option(encoder, SPNG_IMG_COMPRESSION_LEVEL, 1));
    ENCODE_CHECK(spng_set_option(encoder, SPNG_FILTER_CHOICE, SPNG_FILTER_CHOICE_SUB));
    ENCODE_CHECK(spng_set_ihdr(encoder, &header));
    ENCODE_CHECK(spng_encode_image(encoder, pixels, pixel_size, SPNG_FMT_PNG, SPNG_ENCODE_FINALIZE));
    *output = spng_get_png_buffer(encoder, output_size, &result);
    if (result) result = -result;
encoded:
    spng_ctx_free(encoder);
    return result;
#undef ENCODE_CHECK
}

/* 0: encoded output, 1: pixels already clean; other results are explicit errors.
 * Input contains only rendering chunks, so returning it cannot retain text,
 * EXIF, ICC, unknown ancillary chunks or a trailer after IEND.
 */
NAI_EXPORT int nai_png_sanitize(const uint8_t *input, size_t input_size,
                                void **output, size_t *output_size) {
    if (!input || !output || !output_size) return -1002;
    *output = NULL;
    *output_size = 0;
    int result = 0;
    void *pixels = NULL;
    spng_ctx *decoder = spng_ctx_new(0);
    spng_ctx *encoder = NULL;
    if (!decoder) return -SPNG_EMEM;

    struct spng_ihdr header;
    struct spng_trns transparency;
    size_t pixel_size = 0;
    int format;
    int has_alpha;
    int changed = 0;

#define CHECK(call) do { result = (call); if (result) { result = -result; goto done; } } while (0)
    CHECK(spng_set_png_buffer(decoder, input, input_size));
    CHECK(spng_get_ihdr(decoder, &header));
    has_alpha = header.color_type == SPNG_COLOR_TYPE_TRUECOLOR_ALPHA ||
                header.color_type == SPNG_COLOR_TYPE_GRAYSCALE_ALPHA ||
                spng_get_trns(decoder, &transparency) == 0;
    format = header.bit_depth == 16 ? SPNG_FMT_RGBA16 : SPNG_FMT_RGBA8;
    CHECK(spng_decoded_image_size(decoder, format, &pixel_size));
    if (pixel_size > (size_t)512 * 1024 * 1024) { result = -1001; goto done; }
    pixels = malloc(pixel_size);
    if (!pixels) { result = -SPNG_EMEM; goto done; }
    CHECK(spng_decode_image(decoder, pixels, pixel_size, format, SPNG_DECODE_TRNS));
    CHECK(spng_decode_chunks(decoder));

    if (has_alpha && header.bit_depth == 16) {
        uint16_t *samples = (uint16_t *)pixels;
        for (size_t i = 3; i < pixel_size / sizeof(uint16_t); i += 4) {
            changed |= samples[i] & 1;
            samples[i] &= (uint16_t)0xfffe;
        }
    } else if (has_alpha) {
        uint8_t *samples = (uint8_t *)pixels;
        for (size_t i = 3; i < pixel_size; i += 4) {
            changed |= samples[i] & 1;
            samples[i] &= 0xfe;
        }
    }
    if (!changed) { result = 1; goto done; }

    encoder = spng_ctx_new(SPNG_CTX_ENCODER);
    if (!encoder) { result = -SPNG_EMEM; goto done; }
    header.color_type = SPNG_COLOR_TYPE_TRUECOLOR_ALPHA;
    header.bit_depth = header.bit_depth == 16 ? 16 : 8;
    header.interlace_method = 0;
    CHECK(spng_set_option(encoder, SPNG_ENCODE_TO_BUFFER, 1));
    CHECK(spng_set_option(encoder, SPNG_IMG_COMPRESSION_LEVEL, 1));
    CHECK(spng_set_option(encoder, SPNG_FILTER_CHOICE, SPNG_FILTER_CHOICE_SUB));
    CHECK(spng_set_ihdr(encoder, &header));
    CHECK(spng_encode_image(encoder, pixels, pixel_size, SPNG_FMT_PNG, SPNG_ENCODE_FINALIZE));
    *output = spng_get_png_buffer(encoder, output_size, &result);
    if (result) { result = -result; goto done; }

done:
    free(pixels);
    spng_ctx_free(encoder);
    spng_ctx_free(decoder);
    return result;
#undef CHECK
}
