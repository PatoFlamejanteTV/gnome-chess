export default {
    // Repeatedly run optimizations until the result is stable
    multipass: true,
    plugins: [
        {
            name: 'preset-default',
            params: {
                overrides: {
                    // Remove the viewBox attribute (saves bytes, but may affect scaling)
                    removeViewBox: true,
                    // Aggressively round numeric values to 1 decimal place (best for size)
                    cleanupNumericValues: {
                        floatPrecision: 1,
                    },
                    // Convert all basic shapes to paths to find the smallest representation
                    convertShapeToPath: true,
                    // Merge multiple paths into one to reduce markup
                    mergePaths: true,
                },
            },
        },
        // Force removal of all metadata and editor-specific attributes
        'removeDimensions',
        'removeXMLNS',
        'removeScriptElement',
        'removeStyleElement',
        'removeOffCanvasPaths',
        'removeRasterImages', // Remove base64 encoded images to save space
        {
            name: 'cleanupIds',
            params: {
                minify: true, // Shorten IDs to single characters
                remove: true, // Remove unused IDs entirely
            },
        },
    ],
};
