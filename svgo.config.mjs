export default {
    multipass: true, // Crucial for maximum compression
    plugins: [
        {
            name: 'preset-default',
            params: {
                overrides: {
                    // Aggressive numeric rounding
                    cleanupNumericValues: { floatPrecision: 1 },
                    convertPathData: { floatPrecision: 1 },
                    // Keep these in the preset
                    convertShapeToPath: true,
                    mergePaths: true,
                },
            },
        },
        // Standalone plugins (moved outside preset to avoid warnings)
        'removeViewBox',
        'removeDimensions',
        'removeXMLNS',
        'removeScripts', // Renamed from removeScriptElement
        'removeStyleElement',
        'removeOffCanvasPaths',
        'removeRasterImages',
        {
            name: 'cleanupIds',
            params: {
                minify: true,
                remove: true,
            },
        },
        {
            name: 'sortAttrs', // Sorts attributes to improve Gzip/Brotli compression
            params: {
                xmlnsOrder: 'alphabetical',
            },
        },
    ],
};
