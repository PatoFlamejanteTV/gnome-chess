// Configs for SVGO, a tool to compress SVGs
// https://github.com/svg/svgo

export default {
    multipass: true, // Crucial for maximum compression
    plugins: [
        {
            name: 'preset-default',
            params: {
                overrides: {
                    // Aggressive numeric rounding

                    // small note here that rounding stuff make it
                    // less precise, so be careful with it in logos and stuff
                    // in case you want to use the same preset as mine.

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
