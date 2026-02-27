( function() {
    "use strict";

    // =========================================================================
    // STATE
    // =========================================================================

    const state = {
        selectedObjectId: null,
        selectedObjectType: null,  // "emitter" or "image"
        selectedObjectName: null,
        objects: [],               // unified list: [{ id, name, type, selected }]
        templates: [],
        canUndo: false,
        canRedo: false,
        currentParams: {},
        currentImageProps: {},
        _loadTimeout: null,
        uploadedTextures: {},
        particlePresets: [],
        backgroundPresets: [],
    };

    // =========================================================================
    // PARAMETER RANGES
    // =========================================================================

    // Single source of truth for valid bounds; also used to clamp imported JSON values
    var PARAM_RANGES = {
        // Emission
        maxParticles:                { min: 1,     max: 2000, desc: "Maximum number of live particles at once" },
        duration:                    { min: 0,     max: 30,   desc: "How long the emitter runs in seconds (0 = infinite)" },

        // Lifespan
        particleLifespan:            { min: 0.01,  max: 30,   desc: "Base lifetime of each particle in seconds" },
        particleLifespanVariance:    { min: 0,     max: 15,   desc: "Random variation added/subtracted from lifespan" },

        // Direction
        angle:                       { min: -360,  max: 360,  desc: "Base emission angle in degrees (0 = right, 90 = up)" },
        angleVariance:               { min: 0,     max: 360,  desc: "Random spread around the emission angle" },

        // Gravity mode: linear motion
        speed:                       { min: 0,     max: 1000, desc: "Initial speed of particles in pixels/sec" },
        speedVariance:               { min: 0,     max: 500,  desc: "Random variation in initial speed" },
        sourcePositionVariancex:     { min: 0,     max: 2000, desc: "Horizontal spawn area spread in pixels" },
        sourcePositionVariancey:     { min: 0,     max: 2000, desc: "Vertical spawn area spread in pixels" },
        gravityx:                    { min: -500,  max: 500,  desc: "Horizontal gravity acceleration (pixels/sec\u00B2)" },
        gravityy:                    { min: -500,  max: 500,  desc: "Vertical gravity acceleration (pixels/sec\u00B2)" },
        radialAcceleration:          { min: -500,  max: 500,  desc: "Acceleration toward/away from emitter center" },
        radialAccelVariance:         { min: 0,     max: 500,  desc: "Random variation in radial acceleration" },
        tangentialAcceleration:      { min: -500,  max: 500,  desc: "Acceleration perpendicular to radial direction" },
        tangentialAccelVariance:     { min: 0,     max: 500,  desc: "Random variation in tangential acceleration" },

        // Radial mode: orbital motion
        maxRadius:                   { min: 0,     max: 500,  desc: "Starting orbital radius in pixels" },
        maxRadiusVariance:           { min: 0,     max: 250,  desc: "Random variation in starting radius" },
        minRadius:                   { min: 0,     max: 500,  desc: "Ending orbital radius in pixels" },
        minRadiusVariance:           { min: 0,     max: 250,  desc: "Random variation in ending radius" },
        rotatePerSecond:             { min: -360,  max: 360,  desc: "Orbital rotation speed in degrees/sec" },
        rotatePerSecondVariance:     { min: 0,     max: 360,  desc: "Random variation in rotation speed" },

        // Size
        startParticleSize:           { min: 0,     max: 500,  desc: "Particle size at birth in pixels" },
        startParticleSizeVariance:   { min: 0,     max: 250,  desc: "Random variation in start size" },
        finishParticleSize:          { min: 0,     max: 500,  desc: "Particle size at death in pixels" },
        finishParticleSizeVariance:  { min: 0,     max: 250,  desc: "Random variation in finish size" },

        // Rotation (spin)
        rotationStart:               { min: -360,  max: 360,  desc: "Initial rotation of particle in degrees" },
        rotationStartVariance:       { min: 0,     max: 360,  desc: "Random variation in initial rotation" },
        rotationEnd:                 { min: -360,  max: 360,  desc: "Final rotation of particle in degrees" },
        rotationEndVariance:         { min: 0,     max: 360,  desc: "Random variation in final rotation" },

        // Start color (RGBA 0-1)
        startColorRed:               { min: 0,     max: 1,    desc: "Red channel at birth" },
        startColorGreen:             { min: 0,     max: 1,    desc: "Green channel at birth" },
        startColorBlue:              { min: 0,     max: 1,    desc: "Blue channel at birth" },
        startColorAlpha:             { min: 0,     max: 1,    desc: "Alpha (opacity) at birth" },
        startColorVarianceRed:       { min: 0,     max: 1,    desc: "Random variation in start red" },
        startColorVarianceGreen:     { min: 0,     max: 1,    desc: "Random variation in start green" },
        startColorVarianceBlue:      { min: 0,     max: 1,    desc: "Random variation in start blue" },
        startColorVarianceAlpha:     { min: 0,     max: 1,    desc: "Random variation in start alpha" },

        // Finish color (RGBA 0-1)
        finishColorRed:              { min: 0,     max: 1,    desc: "Red channel at death" },
        finishColorGreen:            { min: 0,     max: 1,    desc: "Green channel at death" },
        finishColorBlue:             { min: 0,     max: 1,    desc: "Blue channel at death" },
        finishColorAlpha:            { min: 0,     max: 1,    desc: "Alpha (opacity) at death" },
        finishColorVarianceRed:      { min: 0,     max: 1,    desc: "Random variation in finish red" },
        finishColorVarianceGreen:    { min: 0,     max: 1,    desc: "Random variation in finish green" },
        finishColorVarianceBlue:     { min: 0,     max: 1,    desc: "Random variation in finish blue" },
        finishColorVarianceAlpha:    { min: 0,     max: 1,    desc: "Random variation in finish alpha" },
    };

    // =========================================================================
    // CONSTANTS
    // =========================================================================

    var PREFIX_CUSTOM = "custom:";
    var PREFIX_PRESET = "preset:";
    var PREFIX_UPLOADED = "uploaded:";
    var VALUE_UPLOAD = "upload";
    var TYPE_EMITTER = "emitter";
    var TYPE_IMAGE = "image";
    var CALLLUA_TIMEOUT = 5000;
    var STORAGE_KEY = "solar2d-particle-editor-state";
    var SCENES_STORAGE_KEY = "solar2d-particle-editor-scenes";
    var UPLOADED_IMAGES_KEY = "solar2d-particle-editor-uploaded-images";
    var AUTOSAVE_INTERVAL = 15000; // 15 seconds


    var _suppressClampToast = false;

    /**
     * Clamps a parameter value to its valid range. Shows toast if value was clamped (unless suppressed).
     * @param {string} paramName - The parameter name (key in PARAM_RANGES)
     * @param {number|string} value - The value to clamp
     * @returns {number} The clamped value
     */
    function clampParam( paramName, value ) {
        var range = PARAM_RANGES[paramName];
        if ( !range ) return value;
        var num = parseFloat( value );
        if ( isNaN( num ) ) return range.min;
        var clamped = Math.max( range.min, Math.min( range.max, num ) );
        if ( clamped !== num && !_suppressClampToast ) {
            showToast( paramName + " clamped to " + clamped + " (range: " + range.min + "\u2013" + range.max + ")" );
        }
        return clamped;
    }

    /**
     * Converts UI duration (0 = infinite) to Lua duration (-1 = infinite).
     * @param {number} uiValue
     * @returns {number}
     */
    function uiDurationToLua( uiValue ) {
        return uiValue === 0 ? -1 : uiValue;
    }

    /**
     * Converts Lua duration (-1 = infinite) to UI duration (0 = infinite).
     * @param {number} luaValue
     * @returns {number}
     */
    function luaDurationToUI( luaValue ) {
        return ( luaValue < 0 ) ? 0 : luaValue;
    }

    /**
     * Clamps a parameter and converts duration for Lua.
     * @param {string} paramName
     * @param {number|string} value
     * @returns {number}
     */
    function clampForLua( paramName, value ) {
        var clamped = clampParam( paramName, value );
        if ( paramName === "duration" ) {
            return uiDurationToLua( clamped );
        }
        return clamped;
    }

    // =========================================================================
    // LUA BRIDGE
    // =========================================================================

    // Called by parentBridge.js (inside the iframe) to bubble Lua events up to this page
    window.dispatchSolarEvent = function( eventData ) {
        const event = new CustomEvent( "solarEvent", { detail: eventData } );
        window.dispatchEvent( event );
    };

    /**
     * Fire-and-forget: sends a command to the Lua bridge without expecting a return value.
     * @param {string} method - The Lua handler method name
     * @param {...*} args - Arguments to pass to the handler
     */
    function callLua( method ) {
        const args = Array.prototype.slice.call( arguments, 1 );
        const iframe = document.getElementById( "solar2d-iframe" );
        if ( !iframe || !iframe.contentWindow ) {
            console.warn( "Solar2D iframe not available" );
            return;
        }
        iframe.contentWindow.postMessage( {
            type: "callLua",
            method: method,
            args: args,
            id: null,
        }, "*" );
    }

    let _nextCallId = 0;
    const _pendingCallbacks = {};

    /**
     * Promise-based: sends a command and resolves with the Lua return value.
     * @param {string} method - The Lua handler method name
     * @param {...*} args - Arguments to pass to the handler
     * @returns {Promise<*>} Resolves with the handler's return value
     */
    function callLuaAsync( method ) {
        const args = Array.prototype.slice.call( arguments, 1 );
        const iframe = document.getElementById( "solar2d-iframe" );

        return new Promise( function( resolve, reject ) {
            if ( !iframe || !iframe.contentWindow ) {
                reject( new Error( "Solar2D iframe not available" ) );
                return;
            }

            const id = "call_" + ( ++_nextCallId );
            let settled = false;

            _pendingCallbacks[id] = {
                resolve: function( result ) {
                    if ( settled ) return;
                    settled = true;
                    delete _pendingCallbacks[id];
                    resolve( result );
                },
                reject: function( err ) {
                    if ( settled ) return;
                    settled = true;
                    delete _pendingCallbacks[id];
                    reject( err );
                },
            };

            iframe.contentWindow.postMessage( {
                type: "callLua",
                method: method,
                args: args,
                id: id,
            }, "*" );

            setTimeout( function() {
                if ( !settled ) {
                    settled = true;
                    delete _pendingCallbacks[id];
                    reject( new Error( "callLua timeout: " + method ) );
                }
            }, CALLLUA_TIMEOUT );
        } );
    }

    /**
     * Handles async Lua bridge response, resolving or rejecting the pending promise.
     * @param {Object} data - Response data with id, result, and optional error
     */
    function onCallLuaResponse( data ) {
        const callback = _pendingCallbacks[data.id];
        if ( !callback ) return;
        delete _pendingCallbacks[data.id];

        if ( data.error ) {
            callback.reject( new Error( data.error ) );
        } else {
            callback.resolve( data.result );
        }
    }

    // =========================================================================
    // SOLAR EVENT LISTENER
    // =========================================================================

    window.addEventListener( "solarEvent", function( e ) {
        const detail = e.detail;
        const name = detail.name;
        const data = detail.data;

        switch ( name ) {
            case "ready":
                onReady( data );
                break;
            case "objectListChanged":
                onObjectListChanged( data );
                break;
            case "objectSelected":
                onObjectSelected( data );
                break;
            case "emitterListChanged":
                onObjectListChanged( { objects: data.emitters } );
                break;
            case "emitterSelected":
                onObjectSelected( { id: data.id, type: TYPE_EMITTER, name: data.name, params: data.params, textureInfo: data.textureInfo } );
                break;
            case "historyChanged":
                onHistoryChanged( data );
                break;
            case "stateRestored":
                onStateRestored( data );
                break;
            case "imagePropertyChanged":
                onImagePropertyChanged( data );
                break;
            case "callLuaResponse":
                onCallLuaResponse( data );
                break;
            case "viewChanged":
                onViewChanged( data );
                break;
        }
    } );

    // =========================================================================
    // EVENT HANDLERS
    // =========================================================================

    /**
     * Handles the Solar2D "ready" event; initializes state, renders UI, and starts autosave.
     * @param {Object} data - Contains objects, templates, canUndo, canRedo.
     */
    function onReady( data ) {
        hideIframeLoading();

        state.objects = data.objects || data.emitters || [];
        state.templates = data.templates || [];
        state.canUndo = data.canUndo || false;
        state.canRedo = data.canRedo || false;

        renderObjectList( state.objects );
        renderTemplateDropdown( state.templates );
        updateUndoRedoButtons();

        if ( state.objects.length > 0 ) {
            const selected = state.objects.find( function( o ) { return o.selected; } );
            if ( selected ) {
                state.selectedObjectId = selected.id;
                state.selectedObjectType = selected.type || TYPE_EMITTER;
                state.selectedObjectName = selected.name;
                callLua( "selectObject", selected.id, state.selectedObjectType );
            }
        }

        updateExportState();
        updateTemplateState();
        setupAutoSave();
        applyPendingRestore();
        restoreBackgroundToLua();

        // Apply saved guide settings to Lua
        var savedGrid = localStorage.getItem( "grid-visible" );
        callLua( "setGridEnabled", savedGrid === "true" );

        var savedBounds = localStorage.getItem( "emitter-bounds-mode" ) || "hidden";
        callLua( "setEmitterBoundsMode", savedBounds );

        var savedGridColor = localStorage.getItem( "grid-color" );
        if ( savedGridColor ) {
            var gcRgb = hexToRgb( savedGridColor );
            callLua( "setGridColor", gcRgb.r, gcRgb.g, gcRgb.b );
        }

        var savedBoundsColor = localStorage.getItem( "bounds-color" );
        if ( savedBoundsColor ) {
            var bcRgb = hexToRgb( savedBoundsColor );
            callLua( "setBoundsColor", bcRgb.r, bcRgb.g, bcRgb.b );
        }
    }

    /**
     * Updates the UI when the object list changes in Solar2D.
     * @param {Object} data - Contains objects array.
     */
    function onObjectListChanged( data ) {
        state.objects = data.objects || [];
        renderObjectList( state.objects );
        updateExportState();
    }

    /**
     * Updates the UI when an object is selected in Solar2D. Shows emitter params or image properties.
     * @param {Object} data - Contains id, type, name, params/properties, textureInfo.
     */
    function onObjectSelected( data ) {
        state.selectedObjectId = data.id;
        state.selectedObjectType = data.type || null;
        state.selectedObjectName = data.name || null;

        var paramsContainer = document.getElementById( "params-container" );
        var imageParamsContainer = document.getElementById( "image-params-container" );

        if ( data.type === TYPE_EMITTER && data.id && data.params ) {
            state.currentParams = data.params;
            updateAllInputs( data.params );
            setParamsContainerEnabled( true );
            updateTextureUI( data.textureInfo );
            if ( paramsContainer ) paramsContainer.style.display = "";
            if ( imageParamsContainer ) imageParamsContainer.style.display = "none";
        } else if ( data.type === TYPE_IMAGE && data.id ) {
            state.currentImageProps = data.properties || {};
            updateImageInputs( data.properties );
            rebuildImageSwitchDropdown();
            if ( paramsContainer ) paramsContainer.style.display = "none";
            if ( imageParamsContainer ) imageParamsContainer.style.display = "";
        } else {
            state.currentParams = {};
            state.currentImageProps = {};
            setParamsContainerEnabled( false );
            if ( paramsContainer ) paramsContainer.style.display = "";
            if ( imageParamsContainer ) imageParamsContainer.style.display = "none";
        }

        highlightSelectedObject( data.id );
        updateExportHeader();
        updateExportState();
        updateTemplateState();
    }

    /**
     * Updates undo/redo button state and tooltips when history changes.
     * @param {Object} data - Contains canUndo, canRedo, undoDescription, redoDescription.
     */
    function onHistoryChanged( data ) {
        state.canUndo = data.canUndo;
        state.canRedo = data.canRedo;
        state.undoDescription = data.undoDescription || null;
        state.redoDescription = data.redoDescription || null;
        updateUndoRedoButtons();
    }

    /**
     * Handles full state restoration after undo/redo.
     * @param {Object} data - Contains objects, selectedId, selectedType, params, textureInfo, imageProperties.
     */
    function onStateRestored( data ) {
        state.objects = data.objects || [];
        state.selectedObjectId = data.selectedId;
        state.selectedObjectType = data.selectedType || TYPE_EMITTER;
        renderObjectList( state.objects );

        var paramsContainer = document.getElementById( "params-container" );
        var imageParamsContainer = document.getElementById( "image-params-container" );

        if ( data.selectedType === TYPE_EMITTER && data.params ) {
            state.currentParams = data.params;
            updateAllInputs( data.params );
            setParamsContainerEnabled( true );
            updateTextureUI( data.textureInfo );
            if ( paramsContainer ) paramsContainer.style.display = "";
            if ( imageParamsContainer ) imageParamsContainer.style.display = "none";
        } else if ( data.selectedType === TYPE_IMAGE && data.imageProperties ) {
            state.currentImageProps = data.imageProperties;
            updateImageInputs( data.imageProperties );
            rebuildImageSwitchDropdown();
            if ( paramsContainer ) paramsContainer.style.display = "none";
            if ( imageParamsContainer ) imageParamsContainer.style.display = "";
        } else {
            setParamsContainerEnabled( false );
            if ( paramsContainer ) paramsContainer.style.display = "";
            if ( imageParamsContainer ) imageParamsContainer.style.display = "none";
        }
        updateExportState();
        updateTemplateState();
    }

    /**
     * Updates image property inputs when an image property changes in Solar2D.
     * @param {Object} data - Contains id, x, y, scale, opacity.
     */
    function onImagePropertyChanged( data ) {
        if ( data.id === state.selectedObjectId && state.selectedObjectType === TYPE_IMAGE ) {
            state.currentImageProps = data;
            updateImageInputs( data );
        }
    }

    // =========================================================================
    // IMAGE PROPERTY INPUTS
    // =========================================================================

    /**
     * Syncs image property input elements with given values.
     * @param {Object} properties - Image property values (x, y, scale, opacity).
     */
    function updateImageInputs( properties ) {
        if ( !properties ) return;

        var fields = [ "x", "y", "scale", "opacity" ];
        fields.forEach( function( key ) {
            if ( properties[key] == null ) return;
            var inputs = document.querySelectorAll( "[data-imgprop='" + key + "']" );
            inputs.forEach( function( input ) {
                if ( key === "x" || key === "y" ) {
                    input.value = Math.round( properties[key] );
                } else {
                    input.value = Math.round( properties[key] * 100 ) / 100;
                }
            } );
        } );
    }

    /**
     * Sets up event listeners for image property inputs (range sliders and number fields).
     */
    function setupImagePropertyInputs() {
        var inputs = document.querySelectorAll( "[data-imgprop]" );
        inputs.forEach( function( input ) {
            if ( input.type === "range" ) {
                input.addEventListener( "input", function() {
                    var key = input.getAttribute( "data-imgprop" );
                    var value = parseFloat( input.value );
                    syncImagePairedInput( input, value );
                    if ( state.selectedObjectId && state.selectedObjectType === TYPE_IMAGE ) {
                        callLua( "setImagePropertyPreview", state.selectedObjectId, key, value );
                    }
                } );
                input.addEventListener( "change", function() {
                    if ( state.selectedObjectId && state.selectedObjectType === TYPE_IMAGE ) {
                        callLua( "commitParams" );
                    }
                } );
            } else if ( input.type === "number" ) {
                input.addEventListener( "change", function() {
                    var key = input.getAttribute( "data-imgprop" );
                    var value = parseFloat( input.value );
                    if ( isNaN( value ) ) return;
                    syncImagePairedInput( input, value );
                    if ( state.selectedObjectId && state.selectedObjectType === TYPE_IMAGE ) {
                        callLua( "setImageProperty", state.selectedObjectId, key, value );
                    }
                } );
                input.addEventListener( "input", function() {
                    var value = parseFloat( input.value );
                    if ( !isNaN( value ) ) {
                        syncImagePairedInput( input, value );
                    }
                } );
            }
        } );
    }

    /**
     * Syncs a paired range/number input when one changes.
     * @param {HTMLElement} source - The input that changed.
     * @param {number} value - The new value.
     */
    function syncImagePairedInput( source, value ) {
        var key = source.getAttribute( "data-imgprop" );
        if ( !key ) return;
        var row = source.closest( ".param-row" );
        if ( !row ) return;
        var paired = row.querySelectorAll( "[data-imgprop='" + key + "']" );
        paired.forEach( function( input ) {
            if ( input !== source ) {
                input.value = value;
            }
        } );
    }

    /**
     * Rebuilds the image source dropdown with presets and upload option.
     */
    function rebuildImageSwitchDropdown() {
        var select = document.getElementById( "image-switch-select" );
        if ( !select ) return;

        select.innerHTML = "";

        var currentOpt = document.createElement( "option" );
        currentOpt.value = "";
        currentOpt.textContent = state.selectedObjectName || "-- Current --";
        select.appendChild( currentOpt );

        var presets = state.backgroundPresets || [];
        if ( presets.length > 0 ) {
            var optgroup = document.createElement( "optgroup" );
            optgroup.label = "Presets";
            presets.forEach( function( preset ) {
                var opt = document.createElement( "option" );
                opt.value = PREFIX_PRESET + preset.file;
                opt.textContent = preset.label;
                optgroup.appendChild( opt );
            } );
            select.appendChild( optgroup );
        }

        // Previously uploaded images from localStorage manifest
        var uploaded = getUploadedImagesManifest();
        if ( uploaded.length > 0 ) {
            var uploadedGroup = document.createElement( "optgroup" );
            uploadedGroup.label = "Uploaded";
            uploaded.forEach( function( entry ) {
                var opt = document.createElement( "option" );
                opt.value = PREFIX_UPLOADED + entry.file;
                opt.textContent = entry.label;
                uploadedGroup.appendChild( opt );
            } );
            select.appendChild( uploadedGroup );
        }

        var uploadOpt = document.createElement( "option" );
        uploadOpt.value = VALUE_UPLOAD;
        uploadOpt.textContent = "Upload new...";
        select.appendChild( uploadOpt );
    }

    /**
     * Sets up the image switch dropdown for replacing image sources.
     */
    function setupImageSwitch() {
        var select = document.getElementById( "image-switch-select" );
        if ( !select ) return;

        select.addEventListener( "change", function() {
            var value = select.value;
            if ( !value || !state.selectedObjectId || state.selectedObjectType !== TYPE_IMAGE ) return;

            if ( value === VALUE_UPLOAD ) {
                var fileInput = document.createElement( "input" );
                fileInput.type = "file";
                fileInput.accept = "image/png,image/jpeg,image/gif,image/webp";
                fileInput.addEventListener( "change", function() {
                    var file = fileInput.files[0];
                    if ( !file ) return;
                    var reader = new FileReader();
                    reader.onload = function( e ) {
                        var dataUrl = e.target.result;
                        var img = new Image();
                        img.onload = function() {
                            var label = file.name.replace( /\.[^.]+$/, "" );
                            ensurePngDataUrl( dataUrl, function( pngDataUrl ) {
                                callLua( "replaceImage",
                                    state.selectedObjectId,
                                    pngDataUrl,
                                    file.name,
                                    label,
                                    img.naturalWidth,
                                    img.naturalHeight
                                );
                                // Persist to manifest and refresh dropdown
                                addToUploadedImagesManifest( file.name, label, pngDataUrl );
                                rebuildImageSwitchDropdown();
                            } );
                        };
                        img.src = dataUrl;
                    };
                    reader.readAsDataURL( file );
                } );
                fileInput.click();
                select.value = "";
            } else if ( value.indexOf( PREFIX_PRESET ) === 0 ) {
                var filename = value.substring( PREFIX_PRESET.length );
                var imageUrl = "solar2d/src/assets/images/" + filename;
                var preset = ( state.backgroundPresets || [] ).find( function( p ) {
                    return p.file === filename;
                } );
                var label = preset ? preset.label : filename.replace( /\.[^.]+$/, "" );
                var img = new Image();
                img.onload = function() {
                    var canvas = document.createElement( "canvas" );
                    canvas.width = img.naturalWidth;
                    canvas.height = img.naturalHeight;
                    canvas.getContext( "2d" ).drawImage( img, 0, 0 );
                    var dataUrl = canvas.toDataURL( "image/png" );
                    ensurePngDataUrl( dataUrl, function( pngDataUrl ) {
                        callLua( "replaceImage",
                            state.selectedObjectId,
                            pngDataUrl,
                            filename,
                            label,
                            img.naturalWidth,
                            img.naturalHeight
                        );
                    } );
                };
                img.src = imageUrl;
                select.value = "";
            } else if ( value.indexOf( PREFIX_UPLOADED ) === 0 ) {
                var uploadedFile = value.substring( PREFIX_UPLOADED.length );
                var manifest = getUploadedImagesManifest();
                var entry = manifest.find( function( e ) { return e.file === uploadedFile; } );
                if ( entry ) {
                    var uImg = new Image();
                    uImg.onload = function() {
                        ensurePngDataUrl( entry.dataUrl, function( pngDataUrl ) {
                            callLua( "replaceImage",
                                state.selectedObjectId,
                                pngDataUrl,
                                entry.file,
                                entry.label,
                                uImg.naturalWidth,
                                uImg.naturalHeight
                            );
                        } );
                    };
                    uImg.src = entry.dataUrl;
                }
                select.value = "";
            }
        } );
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    /**
     * Main initialization function; sets up all UI event listeners and initial state.
     */
    function initUI() {
        setupSectionToggles();
        setupAddEmitter();
        setupTemplateLoad();
        setupParameterInputs();
        setupColorPickers();
        setupEmitterTypeListener();
        setupBlendPresets();
        setupBlendManualSync();
        setupUndoRedo();
        setupShortcutsOverlay();
        setupResetPosition();
        setupResetView();
        setupExport();
        setupTextureUpload();
        setupUIScale();
        setupTexturePresets();
        setupTextureRemove();
        setupImportTemplate();
        // Reset background color on every fresh load (restored sessions re-apply their color)
        localStorage.removeItem( "bg-color" );
        setupBackgroundColor();
        setupGuides();
        setupContentArea();
        setupPlaybackControls();
        setupDragAndDrop();
        setupAddImage();
        setupImagePropertyInputs();
        setupImageSwitch();
        setupScenes();
        setupClearScene();
        setupClearStorage();
        setupIframeLoading();
        checkAutoRestore();
        fetchAssetManifests();
    }

    /**
     * Fetches particle texture and background image manifest files from the server.
     */
    function fetchAssetManifests() {
        fetch( "solar2d/src/assets/particles/manifest.json" )
            .then( function( r ) { return r.json(); } )
            .then( function( list ) {
                state.particlePresets = list;
                rebuildTextureDropdown();
            } )
            .catch( function( err ) {
                console.warn( "Failed to load particle manifest:", err );
            } );

        fetch( "solar2d/src/assets/images/manifest.json" )
            .then( function( r ) { return r.json(); } )
            .then( function( list ) {
                state.backgroundPresets = list;
                rebuildImageSwitchDropdown();
            } )
            .catch( function( err ) {
                console.warn( "Failed to load background manifest:", err );
            } );
    }

    document.addEventListener( "DOMContentLoaded", initUI );

    // =========================================================================
    // TOAST NOTIFICATIONS
    // =========================================================================

    /**
     * Displays a temporary notification toast at the bottom of the screen.
     * @param {string} message - The message to display
     * @param {number} [duration=3000] - Time in ms before the toast fades out
     */
    function showToast( message, duration ) {
        duration = duration || 3000;
        const container = document.getElementById( "toast-container" );
        if ( !container ) return;

        const toast = document.createElement( "div" );
        toast.className = "toast";
        toast.textContent = message;
        container.appendChild( toast );

        // Trigger reflow for animation
        toast.offsetHeight;
        toast.classList.add( "show" );

        setTimeout( function() {
            toast.classList.remove( "show" );
            setTimeout( function() {
                if ( toast.parentNode ) {
                    toast.parentNode.removeChild( toast );
                }
            }, 300 );
        }, duration );
    }

    // =========================================================================
    // PARAMS CONTAINER ENABLE/DISABLE
    // =========================================================================

    /**
     * Enables or disables all inputs in the parameter controls panel.
     * @param {boolean} enabled
     */
    function setParamsContainerEnabled( enabled ) {
        const container = document.getElementById( "params-container" );
        if ( !container ) return;

        if ( enabled ) {
            container.classList.remove( "disabled" );
        } else {
            container.classList.add( "disabled" );
        }

        const inputs = container.querySelectorAll( "input, select" );
        inputs.forEach( function( input ) {
            input.disabled = !enabled;
        } );
    }

    // =========================================================================
    // EXPORT STATE (enable/disable buttons)
    // =========================================================================

    /** Enables/disables export buttons based on current selection state. */
    function updateExportState() {
        var hasEmitters = state.objects.some( function( o ) { return o.type !== TYPE_IMAGE; } );
        var hasSelectedEmitter = !!state.selectedObjectId && state.selectedObjectType === TYPE_EMITTER;

        const btnJson = document.getElementById( "btn-export-json" );
        const btnPng = document.getElementById( "btn-export-png" );
        const btnZip = document.getElementById( "btn-export-zip" );
        const btnAllZip = document.getElementById( "btn-export-all-zip" );

        if ( btnJson ) btnJson.disabled = !hasSelectedEmitter;
        if ( btnPng ) btnPng.disabled = !hasSelectedEmitter;
        if ( btnZip ) btnZip.disabled = !hasSelectedEmitter;
        if ( btnAllZip ) btnAllZip.disabled = !hasEmitters;
    }

    /** Updates the export section header to show the selected object's name. */
    function updateExportHeader() {
        const header = document.getElementById( "export-current-header" );
        const message = document.getElementById( "export-current-message" );
        if ( !header ) return;

        if ( state.selectedObjectType === TYPE_EMITTER && state.selectedObjectName ) {
            header.textContent = "EXPORT EMITTER: " + state.selectedObjectName;
            if ( message ) { message.style.display = "none"; message.textContent = ""; }
        } else {
            header.textContent = "SELECT AN EMITTER TO EXPORT";
            if ( message ) { message.style.display = "none"; message.textContent = ""; }
        }
    }

    // =========================================================================
    // SECTION TOGGLE
    // =========================================================================

    /** Sets up collapsible section headers in the right sidebar. */
    function setupSectionToggles() {
        const headers = document.querySelectorAll( ".section-header[data-toggle]" );
        headers.forEach( function( header ) {
            header.setAttribute( "tabindex", "0" );
            header.setAttribute( "role", "button" );
            const isCollapsedInit = header.parentElement.classList.contains( "collapsed" );
            header.setAttribute( "aria-expanded", isCollapsedInit ? "false" : "true" );

            function toggleSection() {
                const section = header.parentElement;
                const content = section.querySelector( ".section-content" );
                const icon = header.querySelector( ".toggle-icon" );

                if ( !content ) return;

                const isCollapsed = content.style.display === "none";
                content.style.display = isCollapsed ? "block" : "none";
                icon.innerHTML = isCollapsed ? "\u25BC" : "\u25B6";
                section.classList.toggle( "collapsed", !isCollapsed );
                header.setAttribute( "aria-expanded", isCollapsed ? "true" : "false" );
            }

            header.addEventListener( "click", toggleSection );
            header.addEventListener( "keydown", function( e ) {
                if ( e.key === "Enter" || e.key === " " ) {
                    e.preventDefault();
                    toggleSection();
                }
            } );
        } );
    }

    // =========================================================================
    // EMITTER LIST
    // =========================================================================

    /**
     * Renders the object list in the left sidebar with badges, rename, delete, and duplicate buttons.
     * @param {Array<Object>} objects - Array of {id, name, type, selected} objects.
     */
    function renderObjectList( objects ) {
        const list = document.getElementById( "object-list" );
        if ( !list ) return;
        list.innerHTML = "";

        objects.forEach( function( obj ) {
            const li = document.createElement( "li" );
            li.setAttribute( "data-id", obj.id );
            li.setAttribute( "data-type", obj.type || TYPE_EMITTER );
            li.draggable = true;
            if ( obj.selected || obj.id === state.selectedObjectId ) {
                li.classList.add( "selected" );
            }

            // Type badge
            const typeBadge = document.createElement( "span" );
            typeBadge.className = "object-type-badge " + ( obj.type === TYPE_IMAGE ? "badge-image" : "badge-emitter" );
            typeBadge.textContent = obj.type === TYPE_IMAGE ? "I" : "E";
            typeBadge.title = obj.type === TYPE_IMAGE ? "Image" : "Emitter";

            const nameSpan = document.createElement( "span" );
            nameSpan.className = "emitter-name";
            nameSpan.textContent = obj.name;
            nameSpan.addEventListener( "dblclick", function( e ) {
                e.stopPropagation();
                startRename( li, obj.id, obj.name, obj.type || TYPE_EMITTER );
            } );

            const dupBtn = document.createElement( "button" );
            dupBtn.className = "btn-duplicate";
            dupBtn.title = "Duplicate";
            dupBtn.setAttribute( "aria-label", "Duplicate " + obj.name );
            dupBtn.textContent = "\u29C9";
            dupBtn.addEventListener( "click", function( e ) {
                e.stopPropagation();
                if ( obj.type === TYPE_IMAGE ) {
                    callLua( "duplicateImage", obj.id );
                } else {
                    callLua( "duplicateEmitter", obj.id );
                }
            } );

            const delBtn = document.createElement( "button" );
            delBtn.className = "btn-delete";
            delBtn.title = "Delete";
            delBtn.setAttribute( "aria-label", "Delete " + obj.name );
            delBtn.textContent = "\u00D7";
            delBtn.addEventListener( "click", function( e ) {
                e.stopPropagation();
                var typeLabel = obj.type === TYPE_IMAGE ? "image" : "emitter";
                if ( confirm( "Delete " + typeLabel + " \"" + obj.name + "\"?" ) ) {
                    if ( obj.type === TYPE_IMAGE ) {
                        callLua( "removeImage", obj.id );
                    } else {
                        callLua( "removeEmitter", obj.id );
                    }
                }
            } );

            li.appendChild( typeBadge );
            li.appendChild( nameSpan );
            li.appendChild( dupBtn );
            li.appendChild( delBtn );

            li.addEventListener( "click", function() {
                var objType = obj.type || TYPE_EMITTER;
                callLua( "selectObject", obj.id, objType );
                state.selectedObjectId = obj.id;
                state.selectedObjectType = objType;
                state.selectedObjectName = obj.name;
                highlightSelectedObject( obj.id );
                updateExportHeader();
            } );

            list.appendChild( li );
        } );
    }

    /**
     * Highlights the selected object in the object list.
     * @param {string} id - The object ID to highlight.
     */
    function highlightSelectedObject( id ) {
        const items = document.querySelectorAll( "#object-list li" );
        items.forEach( function( li ) {
            li.classList.toggle( "selected", li.getAttribute( "data-id" ) === id );
        } );
    }

    /** Sets up drag-and-drop reordering for the object list. */
    function setupDragAndDrop() {
        const list = document.getElementById( "object-list" );
        if ( !list ) return;

        let draggedElement = null;

        list.addEventListener( "dragstart", function( e ) {
            if ( e.target.tagName !== "LI" ) return;
            draggedElement = e.target;
            draggedElement.classList.add( "dragging" );
            e.dataTransfer.effectAllowed = "move";
            e.dataTransfer.setData( "text/html", draggedElement.innerHTML );
        } );

        list.addEventListener( "dragover", function( e ) {
            e.preventDefault();
            e.dataTransfer.dropEffect = "move";

            var dropTarget = e.target.closest( "li" );
            var items = document.querySelectorAll( "#object-list li" );
            items.forEach( function( item ) {
                item.classList.remove( "drag-over-top", "drag-over-bottom" );
            } );

            if ( dropTarget && dropTarget !== draggedElement ) {
                var rect = dropTarget.getBoundingClientRect();
                var midY = rect.top + rect.height / 2;
                if ( e.clientY < midY ) {
                    dropTarget.classList.add( "drag-over-top" );
                } else {
                    dropTarget.classList.add( "drag-over-bottom" );
                }
                list.classList.remove( "drag-over-end" );
            } else if ( !dropTarget ) {
                list.classList.add( "drag-over-end" );
            }
        } );

        list.addEventListener( "dragleave", function( e ) {
            if ( e.target.tagName === "LI" ) {
                e.target.classList.remove( "drag-over-top", "drag-over-bottom" );
            }
        } );

        list.addEventListener( "drop", function( e ) {
            e.preventDefault();
            e.stopPropagation();

            var dropTarget = e.target.closest( "li" );
            if ( dropTarget === draggedElement ) return;

            var draggedId = draggedElement.getAttribute( "data-id" );
            var allItems = Array.from( document.querySelectorAll( "#object-list li" ) );
            var newIndex;

            if ( !dropTarget ) {
                // Dropped in empty space below last item — move to end (foreground)
                newIndex = allItems.length + 1; // Lua 1-based: after last position
            } else {
                var targetIndex = allItems.indexOf( dropTarget );
                var rect = dropTarget.getBoundingClientRect();
                var midY = rect.top + rect.height / 2;
                if ( e.clientY < midY ) {
                    newIndex = targetIndex + 1; // Lua 1-based: place AT target position
                } else {
                    newIndex = targetIndex + 2; // Lua 1-based: place AFTER target
                }
                dropTarget.classList.remove( "drag-over-top", "drag-over-bottom" );
            }

            callLua( "reorderObject", draggedId, newIndex );

            // Workaround: when moving to the end of the list, Lua's forward-move
            // adjustment prevents the item from reaching the last position.
            // Send a second command to backward-move the last item, which pushes
            // the dragged item into the final slot.
            if ( newIndex > allItems.length ) {
                var nonDraggedItems = allItems.filter( function( item ) {
                    return item !== draggedElement;
                } );
                if ( nonDraggedItems.length > 0 ) {
                    var lastItem = nonDraggedItems[ nonDraggedItems.length - 1 ];
                    callLua( "reorderObject", lastItem.getAttribute( "data-id" ), allItems.length - 1 );
                }
            }

            list.classList.remove( "drag-over-end" );
        } );

        list.addEventListener( "dragend", function() {
            if ( draggedElement ) {
                draggedElement.classList.remove( "dragging" );
                draggedElement = null;
            }
            document.querySelectorAll( "#object-list li" ).forEach( function( item ) {
                item.classList.remove( "drag-over-top", "drag-over-bottom" );
            } );
            list.classList.remove( "drag-over-end" );
        } );
    }

    /**
     * Starts inline rename editing for an object in the list.
     * @param {HTMLElement} li - The list item element.
     * @param {string} id - Object ID.
     * @param {string} currentName - Current object name.
     * @param {string} objType - "emitter" or "image".
     */
    function startRename( li, id, currentName, objType ) {
        const nameSpan = li.querySelector( ".emitter-name" );
        const input = document.createElement( "input" );
        input.type = "text";
        input.value = currentName;
        input.style.cssText = "flex:1; background:#2d2d32; color:#e0e0e0; border:1px solid #4a9eff; border-radius:3px; padding:2px 4px; font-size:13px; outline:none;";

        nameSpan.style.display = "none";
        li.insertBefore( input, nameSpan.nextSibling );
        input.focus();
        input.select();

        function finishRename() {
            const newName = input.value.trim();
            if ( newName && newName !== currentName ) {
                callLua( "renameObject", id, newName, objType || TYPE_EMITTER );
                nameSpan.textContent = newName;
                if ( id === state.selectedObjectId ) {
                    state.selectedObjectName = newName;
                    updateExportHeader();
                }
            }
            nameSpan.style.display = "";
            if ( input.parentNode ) {
                input.parentNode.removeChild( input );
            }
        }

        input.addEventListener( "blur", finishRename );
        input.addEventListener( "keydown", function( e ) {
            if ( e.key === "Enter" ) {
                finishRename();
            } else if ( e.key === "Escape" ) {
                nameSpan.style.display = "";
                if ( input.parentNode ) {
                    input.parentNode.removeChild( input );
                }
            }
        } );
    }

    /** Sets up the "Add Emitter" button click handler. */
    function setupAddEmitter() {
        document.getElementById( "btn-add-emitter" ).addEventListener( "click", function() {
            const select = document.getElementById( "template-select" );
            const templateId = select ? select.value : "";
            if ( templateId ) {
                callLua( "createEmitter", templateId );
            } else {
                callLua( "createEmitter" );
            }
        } );
    }

    /** Sets up the "Add Image" button with source picker popup. */
    function setupAddImage() {
        const btn = document.getElementById( "btn-add-image" );
        const fileInput = document.getElementById( "image-add-file" );
        if ( !btn || !fileInput ) return;

        btn.addEventListener( "click", function() {
            showImageSourcePicker( btn );
        } );

        fileInput.addEventListener( "change", function() {
            const file = fileInput.files[0];
            if ( !file ) return;
            const reader = new FileReader();
            reader.onload = function( e ) {
                var dataUrl = e.target.result;
                var img = new Image();
                img.onload = function() {
                    var w = img.naturalWidth;
                    var h = img.naturalHeight;
                    var label = file.name.replace( /\.[^.]+$/, "" );
                    ensurePngDataUrl( dataUrl, function( pngDataUrl ) {
                        callLua( "createImage", pngDataUrl, file.name, label, w, h );
                        // Persist to uploaded images manifest for reuse
                        addToUploadedImagesManifest( file.name, label, pngDataUrl );
                    } );
                };
                img.src = dataUrl;
            };
            reader.readAsDataURL( file );
            fileInput.value = "";
        } );
    }

    // =========================================================================
    // UPLOADED IMAGES MANIFEST (localStorage persistence)
    // =========================================================================

    /** Returns the array of saved uploaded images from localStorage. Each entry: { label, file, dataUrl }. */
    function getUploadedImagesManifest() {
        try {
            var data = localStorage.getItem( UPLOADED_IMAGES_KEY );
            return data ? JSON.parse( data ) : [];
        } catch ( e ) {
            return [];
        }
    }

    /** Saves the uploaded images manifest array to localStorage. */
    function saveUploadedImagesManifest( manifest ) {
        try {
            localStorage.setItem( UPLOADED_IMAGES_KEY, JSON.stringify( manifest ) );
        } catch ( e ) {
            console.warn( "Failed to save uploaded images manifest", e );
        }
    }

    /** Adds an uploaded image to the persistent manifest (deduplicates by filename). */
    function addToUploadedImagesManifest( filename, label, dataUrl ) {
        var manifest = getUploadedImagesManifest();
        // Replace if same filename already exists
        for ( var i = 0; i < manifest.length; i++ ) {
            if ( manifest[i].file === filename ) {
                manifest[i] = { label: label, file: filename, dataUrl: dataUrl };
                saveUploadedImagesManifest( manifest );
                return;
            }
        }
        manifest.push( { label: label, file: filename, dataUrl: dataUrl } );
        saveUploadedImagesManifest( manifest );
    }

    /** Removes an uploaded image from the manifest by filename. */
    function removeFromUploadedImagesManifest( filename ) {
        var manifest = getUploadedImagesManifest();
        manifest = manifest.filter( function( entry ) { return entry.file !== filename; } );
        saveUploadedImagesManifest( manifest );
    }

    /**
     * Shows a popup picker for choosing an image source (presets or upload).
     * @param {HTMLElement} anchorBtn - The button to anchor the popup to.
     */
    function showImageSourcePicker( anchorBtn ) {
        // Remove any existing picker
        var existing = document.querySelector( ".image-source-picker" );
        if ( existing ) {
            existing.parentNode.removeChild( existing );
            return;
        }

        var picker = document.createElement( "div" );
        picker.className = "image-source-picker";

        // Upload option
        var uploadItem = document.createElement( "div" );
        uploadItem.className = "picker-item";
        uploadItem.textContent = "Upload...";
        uploadItem.addEventListener( "click", function() {
            document.getElementById( "image-add-file" ).click();
            closePicker();
        } );
        picker.appendChild( uploadItem );

        // Preset images
        var presets = state.backgroundPresets || [];
        if ( presets.length > 0 ) {
            var header = document.createElement( "div" );
            header.className = "picker-header";
            header.textContent = "Presets";
            picker.appendChild( header );

            presets.forEach( function( preset ) {
                var item = document.createElement( "div" );
                item.className = "picker-item";
                item.textContent = preset.label;
                item.addEventListener( "click", function() {
                    loadPresetImage( preset );
                    closePicker();
                } );
                picker.appendChild( item );
            } );
        }

        // Previously uploaded images (from localStorage manifest)
        var uploaded = getUploadedImagesManifest();
        if ( uploaded.length > 0 ) {
            var uploadedHeader = document.createElement( "div" );
            uploadedHeader.className = "picker-header";
            uploadedHeader.textContent = "Uploaded";
            picker.appendChild( uploadedHeader );

            uploaded.forEach( function( entry ) {
                var row = document.createElement( "div" );
                row.className = "picker-item picker-item-with-remove";

                var label = document.createElement( "span" );
                label.textContent = entry.label;
                label.style.flex = "1";
                label.style.cursor = "pointer";
                label.addEventListener( "click", function() {
                    loadUploadedImage( entry );
                    closePicker();
                } );
                row.appendChild( label );

                var removeBtn = document.createElement( "span" );
                removeBtn.className = "picker-item-remove";
                removeBtn.textContent = "\u00D7";
                removeBtn.title = "Remove from saved";
                removeBtn.addEventListener( "click", function( e ) {
                    e.stopPropagation();
                    removeFromUploadedImagesManifest( entry.file );
                    if ( row.parentNode ) row.parentNode.removeChild( row );
                    // Remove header if no more uploaded items
                    var remaining = picker.querySelectorAll( ".picker-item-with-remove" );
                    if ( remaining.length === 0 && uploadedHeader.parentNode ) {
                        uploadedHeader.parentNode.removeChild( uploadedHeader );
                    }
                } );
                row.appendChild( removeBtn );

                picker.appendChild( row );
            } );
        }

        // Position the picker
        var rect = anchorBtn.getBoundingClientRect();
        picker.style.left = rect.left + "px";
        picker.style.top = ( rect.bottom + 2 ) + "px";
        picker.style.position = "fixed";
        document.body.appendChild( picker );

        function closePicker() {
            if ( picker.parentNode ) {
                picker.parentNode.removeChild( picker );
            }
            document.removeEventListener( "click", onOutsideClick );
        }

        function onOutsideClick( e ) {
            if ( !picker.contains( e.target ) && e.target !== anchorBtn ) {
                closePicker();
            }
        }

        setTimeout( function() {
            document.addEventListener( "click", onOutsideClick );
        }, 0 );
    }

    function loadPresetImage( preset ) {
        var imageUrl = "solar2d/src/assets/images/" + preset.file;
        var img = new Image();
        img.onload = function() {
            var canvas = document.createElement( "canvas" );
            canvas.width = img.naturalWidth;
            canvas.height = img.naturalHeight;
            canvas.getContext( "2d" ).drawImage( img, 0, 0 );
            var dataUrl = canvas.toDataURL( "image/png" );
            ensurePngDataUrl( dataUrl, function( pngDataUrl ) {
                callLua( "createImage", pngDataUrl, preset.file, preset.label, img.naturalWidth, img.naturalHeight );
            } );
        };
        img.src = imageUrl;
    }

    /** Loads a previously uploaded image from its saved dataUrl in the manifest. */
    function loadUploadedImage( entry ) {
        var img = new Image();
        img.onload = function() {
            ensurePngDataUrl( entry.dataUrl, function( pngDataUrl ) {
                callLua( "createImage", pngDataUrl, entry.file, entry.label, img.naturalWidth, img.naturalHeight );
            } );
        };
        img.src = entry.dataUrl;
    }

    // =========================================================================
    // TEMPLATES
    // =========================================================================

    /**
     * Populates the template dropdown with available presets.
     * @param {Array<Object>} templates - Array of {id, name, description}.
     */
    function renderTemplateDropdown( templates ) {
        const select = document.getElementById( "template-select" );
        while ( select.options.length > 1 ) {
            select.remove( 1 );
        }

        templates.forEach( function( template ) {
            const option = document.createElement( "option" );
            option.value = template.id;
            option.textContent = template.name;
            option.title = template.description;
            select.appendChild( option );
        } );
    }

    /** Sets up the template dropdown change handler. */
    function setupTemplateLoad() {
        document.getElementById( "template-select" ).addEventListener( "change", function() {
            const templateId = this.value;
            if ( !templateId ) return;
            const templateName = this.options[this.selectedIndex].text;
            this.selectedIndex = 0;
            callLua( "createEmitter", templateId );
            showToast( "Emitter created: " + templateName );
        } );
    }

    /** Enables/disables import button based on whether an emitter is selected. */
    function updateTemplateState() {
        var importBtn = document.getElementById( "btn-import-template" );
        var isEmitter = state.selectedObjectType === TYPE_EMITTER && !!state.selectedObjectId;

        if ( importBtn ) importBtn.disabled = !isEmitter;
    }

    // =========================================================================
    // IMPORT TEMPLATE (JSON file)
    // =========================================================================

    /** Sets up the JSON template import file input handler. */
    function setupImportTemplate() {
        const btn = document.getElementById( "btn-import-template" );
        const fileInput = document.getElementById( "template-import-file" );
        if ( !btn || !fileInput ) return;

        btn.addEventListener( "click", function() {
            fileInput.click();
        } );

        fileInput.addEventListener( "change", function() {
            const file = fileInput.files[0];
            if ( !file ) return;

            const reader = new FileReader();
            reader.onload = function( e ) {
                try {
                    const imported = JSON.parse( e.target.result );
                    if ( !state.selectedObjectId || state.selectedObjectType !== TYPE_EMITTER ) {
                        showToast( "Select an emitter to import a template" );
                        return;
                    }

                    _suppressClampToast = true;
                    const params = {};
                    for ( const key in imported ) {
                        if ( imported.hasOwnProperty( key )
                             && key !== "name"
                             && key !== "textureBase64"
                             && key !== "textureFilename" ) {
                            if ( key === "duration" ) {
                                var dur = parseFloat( imported[key] );
                                params[key] = ( isNaN( dur ) || dur <= 0 ) ? -1 : Math.min( dur, 30 );
                            } else if ( PARAM_RANGES[key] ) {
                                params[key] = clampParam( key, imported[key] );
                            } else {
                                params[key] = imported[key];
                            }
                        }
                    }
                    _suppressClampToast = false;

                    callLua( "setParams", state.selectedObjectId, params );

                    if ( imported.name ) {
                        callLua( "renameObject", state.selectedObjectId, imported.name, TYPE_EMITTER );
                    }

                    if ( imported.textureBase64 && imported.textureFilename ) {
                        state.uploadedTextures[imported.textureFilename] = {
                            base64: imported.textureBase64,
                            dataUrl: "data:image/png;base64," + imported.textureBase64,
                        };
                        callLua( "setTexture", state.selectedObjectId,
                                 imported.textureBase64, imported.textureFilename );
                        rebuildTextureDropdown();
                    }

                    showToast( "Imported: " + ( imported.name || file.name ) );
                } catch ( err ) {
                    showToast( "Import failed: invalid JSON" );
                    console.error( "Import error:", err );
                }
            };
            reader.readAsText( file );

            fileInput.value = "";
        } );
    }

    // =========================================================================
    // PARAMETER INPUTS
    // =========================================================================

    /**
     * Sets up event listeners for all emitter parameter inputs (range sliders, number fields, selects).
     */
    function setupParameterInputs() {
        const inputs = document.querySelectorAll( "[data-param]" );
        inputs.forEach( function( input ) {
            if ( input.tagName === "SELECT" ) {
                input.addEventListener( "change", function() {
                    const paramName = input.getAttribute( "data-param" );
                    const value = parseFloat( input.value );

                    syncPairedInput( input, input.value );

                    if ( state.selectedObjectId && !isNaN( value ) ) {
                        callLua( "setParam", state.selectedObjectId, paramName, value );
                    }

                    updateColorPreviewIfNeeded( paramName );
                } );
            } else if ( input.type === "range" ) {
                // Preview on drag (setParamPreview = no history push), commit on release
                input.addEventListener( "input", function() {
                    const paramName = input.getAttribute( "data-param" );
                    const clamped = clampParam( paramName, input.value );
                    const luaValue = clampForLua( paramName, input.value );

                    syncPairedInput( input, clamped );

                    if ( state.selectedObjectId && !isNaN( luaValue ) ) {
                        callLua( "setParamPreview", state.selectedObjectId, paramName, luaValue );
                    }

                    updateColorPreviewIfNeeded( paramName );
                } );
                input.addEventListener( "change", function() {
                    if ( state.selectedObjectId ) {
                        callLua( "commitParams" );
                    }
                } );
            } else if ( input.type === "number" ) {
                // Only send on change (blur/enter) to avoid sending partial typed values like "1" of "15"
                input.addEventListener( "change", function() {
                    const paramName = input.getAttribute( "data-param" );
                    const clamped = clampParam( paramName, input.value );
                    const luaValue = clampForLua( paramName, input.value );

                    input.value = clamped;
                    syncPairedInput( input, clamped );

                    if ( state.selectedObjectId && !isNaN( luaValue ) ) {
                        callLua( "setParam", state.selectedObjectId, paramName, luaValue );
                    }

                    updateColorPreviewIfNeeded( paramName );
                } );
                input.addEventListener( "input", function() {
                    const paramName = input.getAttribute( "data-param" );
                    const clamped = clampParam( paramName, input.value );
                    syncPairedInput( input, clamped );
                } );
            }
        } );
    }

    /**
     * Syncs paired range/number inputs when one changes (emitter params).
     * @param {HTMLElement} source - The input element that changed
     * @param {number|string} value - The new value
     */
    function syncPairedInput( source, value ) {
        const paramName = source.getAttribute( "data-param" );
        if ( !paramName ) return;

        const row = source.closest( ".param-row" );
        if ( !row ) return;

        const paired = row.querySelectorAll( "[data-param='" + paramName + "']" );
        paired.forEach( function( input ) {
            if ( input !== source ) {
                input.value = value;
            }
        } );
    }

    /**
     * Updates all parameter input elements to reflect the given values.
     * @param {Object} params - Key-value pairs of parameter names to values
     */
    function updateAllInputs( params ) {
        for ( const key in params ) {
            if ( !params.hasOwnProperty( key ) ) continue;

            var value = params[key];
            if ( key === "duration" ) {
                value = luaDurationToUI( value );
            }
            const inputs = document.querySelectorAll( "[data-param='" + key + "']" );
            inputs.forEach( function( input ) {
                input.value = value;
            } );
        }

        updateEmitterTypeSections( params.emitterType || 0 );
        updateBlendPresetFromParams( params );

        // Sync color picker swatches to match the loaded param values
        var startPicker = document.getElementById( "color-start-picker" );
        if ( startPicker && params.startColorRed !== undefined ) {
            startPicker.value = rgbToHex(
                params.startColorRed,
                params.startColorGreen,
                params.startColorBlue
            );
        }
        var endPicker = document.getElementById( "color-end-picker" );
        if ( endPicker && params.finishColorRed !== undefined ) {
            endPicker.value = rgbToHex(
                params.finishColorRed,
                params.finishColorGreen,
                params.finishColorBlue
            );
        }

        // Texture dropdown is normally synced by updateTextureUI() which knows about
        // custom vs preset textures. This only handles the simple preset-path case.
        const texturePreset = document.getElementById( "texture-preset" );
        if ( texturePreset && params.textureFileName && texturePreset.value.indexOf( PREFIX_CUSTOM ) !== 0 ) {
            texturePreset.value = params.textureFileName;
        }
    }

    // =========================================================================
    // COLOR CONTROLS
    // =========================================================================

    /**
     * Sets up start/end color picker inputs with bidirectional sync to RGBA sliders.
     */
    function setupColorPickers() {
        const startPicker = document.getElementById( "color-start-picker" );
        const endPicker = document.getElementById( "color-end-picker" );

        if ( startPicker ) {
            startPicker.addEventListener( "input", function() {
                const rgb = hexToRgb( startPicker.value );
                setInputValue( "startColorRed", rgb.r );
                setInputValue( "startColorGreen", rgb.g );
                setInputValue( "startColorBlue", rgb.b );

                if ( state.selectedObjectId ) {
                    callLua( "setParamsPreview", state.selectedObjectId, {
                        startColorRed: rgb.r,
                        startColorGreen: rgb.g,
                        startColorBlue: rgb.b,
                    } );
                }
            } );
            startPicker.addEventListener( "change", function() {
                if ( state.selectedObjectId ) {
                    callLua( "commitParams" );
                }
            } );
        }

        if ( endPicker ) {
            endPicker.addEventListener( "input", function() {
                const rgb = hexToRgb( endPicker.value );
                setInputValue( "finishColorRed", rgb.r );
                setInputValue( "finishColorGreen", rgb.g );
                setInputValue( "finishColorBlue", rgb.b );

                if ( state.selectedObjectId ) {
                    callLua( "setParamsPreview", state.selectedObjectId, {
                        finishColorRed: rgb.r,
                        finishColorGreen: rgb.g,
                        finishColorBlue: rgb.b,
                    } );
                }
            } );
            endPicker.addEventListener( "change", function() {
                if ( state.selectedObjectId ) {
                    callLua( "commitParams" );
                }
            } );
        }
    }

    /**
     * Sets the value of all inputs bound to a parameter name.
     * @param {string} paramName - The data-param attribute value
     * @param {number|string} value - The value to set
     */
    function setInputValue( paramName, value ) {
        const inputs = document.querySelectorAll( "[data-param='" + paramName + "']" );
        inputs.forEach( function( input ) {
            input.value = value;
        } );
    }

    /**
     * Gets the current value from the first input bound to a parameter name.
     * @param {string} paramName - The data-param attribute value
     * @returns {string} The input's current value
     */
    function getInputValue( paramName ) {
        const input = document.querySelector( "[data-param='" + paramName + "']" );
        return input ? parseFloat( input.value ) : 0;
    }

    /**
     * Updates the color picker preview swatch when an RGBA slider changes.
     * @param {string} paramName - The parameter that changed
     */
    function updateColorPreviewIfNeeded( paramName ) {
        if ( paramName.indexOf( "startColor" ) === 0 && paramName.indexOf( "Variance" ) === -1 ) {
            var picker = document.getElementById( "color-start-picker" );
            if ( picker ) {
                picker.value = rgbToHex(
                    getInputValue( "startColorRed" ),
                    getInputValue( "startColorGreen" ),
                    getInputValue( "startColorBlue" )
                );
            }
        } else if ( paramName.indexOf( "finishColor" ) === 0 && paramName.indexOf( "Variance" ) === -1 ) {
            var picker = document.getElementById( "color-end-picker" );
            if ( picker ) {
                picker.value = rgbToHex(
                    getInputValue( "finishColorRed" ),
                    getInputValue( "finishColorGreen" ),
                    getInputValue( "finishColorBlue" )
                );
            }
        }
    }


    // =========================================================================
    // EMITTER TYPE SWITCHING
    // =========================================================================

    /**
     * Shows/hides physics sections based on emitter type (gravity vs radial).
     * @param {number|string} emitterType - 0 for gravity, 1 for radial
     */
    function updateEmitterTypeSections( emitterType ) {
        const gravitySection = document.getElementById( "physics-gravity-section" );
        const radialSection = document.getElementById( "physics-radial-section" );

        if ( gravitySection ) {
            gravitySection.style.display = ( emitterType === 0 ) ? "block" : "none";
        }
        if ( radialSection ) {
            radialSection.style.display = ( emitterType === 1 ) ? "block" : "none";
        }
    }

    /**
     * Sets up the emitter type dropdown to toggle physics sections.
     */
    function setupEmitterTypeListener() {
        const selects = document.querySelectorAll( "[data-param='emitterType']" );
        selects.forEach( function( select ) {
            select.addEventListener( "change", function() {
                updateEmitterTypeSections( parseInt( select.value, 10 ) );
            } );
        } );
    }

    // =========================================================================
    // BLEND PRESETS
    // =========================================================================

    // Maps preset names to OpenGL blend function enum values
    const BLEND_PRESETS = {
        additive: { source: 770, destination: 1 },     // SRC_ALPHA, ONE
        normal:   { source: 770, destination: 771 },   // SRC_ALPHA, ONE_MINUS_SRC_ALPHA
        multiply: { source: 774, destination: 0 },     // DST_COLOR, ZERO
        screen:   { source: 1,   destination: 769 },   // ONE, ONE_MINUS_SRC_COLOR
    };

    /**
     * Sets up the blend mode preset dropdown.
     */
    function setupBlendPresets() {
        const preset = document.getElementById( "blend-preset" );
        if ( !preset ) return;

        preset.addEventListener( "change", function() {
            const value = preset.value;
            if ( value === "custom" ) return;

            const config = BLEND_PRESETS[value];
            if ( !config ) return;

            setInputValue( "blendFuncSource", config.source );
            setInputValue( "blendFuncDestination", config.destination );

            const srcSelect = document.querySelector( "select[data-param='blendFuncSource']" );
            const dstSelect = document.querySelector( "select[data-param='blendFuncDestination']" );
            if ( srcSelect ) srcSelect.value = config.source;
            if ( dstSelect ) dstSelect.value = config.destination;

            if ( state.selectedObjectId ) {
                callLua( "setParams", state.selectedObjectId, {
                    blendFuncSource: config.source,
                    blendFuncDestination: config.destination,
                } );
            }
        } );
    }

    function setupBlendManualSync() {
        const srcSelect = document.querySelector( "select[data-param='blendFuncSource']" );
        const dstSelect = document.querySelector( "select[data-param='blendFuncDestination']" );

        /**
         * Syncs blend function dropdowns with the selected preset values.
         */
        function syncBlendPreset() {
            const src = srcSelect ? parseInt( srcSelect.value, 10 ) : 770;
            const dst = dstSelect ? parseInt( dstSelect.value, 10 ) : 1;
            updateBlendPresetFromParams( { blendFuncSource: src, blendFuncDestination: dst } );
        }

        if ( srcSelect ) srcSelect.addEventListener( "change", syncBlendPreset );
        if ( dstSelect ) dstSelect.addEventListener( "change", syncBlendPreset );
    }

    /**
     * Updates the blend preset dropdown to match current parameter values.
     * @param {Object} params - Contains blendFuncSource and blendFuncDestination
     */
    function updateBlendPresetFromParams( params ) {
        const src = params.blendFuncSource;
        const dst = params.blendFuncDestination;
        const preset = document.getElementById( "blend-preset" );
        if ( !preset ) return;

        let matched = "custom";
        for ( const key in BLEND_PRESETS ) {
            if ( BLEND_PRESETS[key].source === src && BLEND_PRESETS[key].destination === dst ) {
                matched = key;
                break;
            }
        }
        preset.value = matched;
    }

    // =========================================================================
    // UNDO / REDO
    // =========================================================================

    /**
     * Sets up undo/redo buttons and Ctrl+Z/Y keyboard shortcuts.
     */
    function setupUndoRedo() {
        document.getElementById( "btn-undo" ).addEventListener( "click", function() {
            callLua( "undo" );
        } );

        document.getElementById( "btn-redo" ).addEventListener( "click", function() {
            callLua( "redo" );
        } );

        document.addEventListener( "keydown", function( e ) {
            if ( e.ctrlKey || e.metaKey ) {
                if ( e.key === "z" && !e.shiftKey ) {
                    e.preventDefault();
                    callLua( "undo" );
                } else if ( e.key === "y" || ( e.key === "z" && e.shiftKey ) ) {
                    e.preventDefault();
                    callLua( "redo" );
                }
            }
        } );
    }

    /**
     * Enables/disables undo/redo buttons based on history state.
     */
    function updateUndoRedoButtons() {
        const undoBtn = document.getElementById( "btn-undo" );
        const redoBtn = document.getElementById( "btn-redo" );

        undoBtn.disabled = !state.canUndo;
        redoBtn.disabled = !state.canRedo;

        undoBtn.title = state.canUndo && state.undoDescription
            ? "Undo: " + state.undoDescription
            : "Undo";
        redoBtn.title = state.canRedo && state.redoDescription
            ? "Redo: " + state.redoDescription
            : "Redo";
    }

    // =========================================================================
    // KEYBOARD SHORTCUTS OVERLAY
    // =========================================================================

    /**
     * Sets up the keyboard shortcuts help modal toggle.
     */
    function setupShortcutsOverlay() {
        var btn = document.getElementById( "btn-shortcuts" );
        var overlay = document.getElementById( "shortcuts-overlay" );
        var closeBtn = document.getElementById( "btn-close-shortcuts" );
        if ( !btn || !overlay ) return;

        function showShortcuts() { overlay.style.display = ""; }
        function hideShortcuts() { overlay.style.display = "none"; }

        btn.addEventListener( "click", showShortcuts );

        if ( closeBtn ) closeBtn.addEventListener( "click", hideShortcuts );

        overlay.addEventListener( "click", function( e ) {
            if ( e.target === overlay ) hideShortcuts();
        } );

        document.addEventListener( "keydown", function( e ) {
            if ( e.key === "Escape" && overlay.style.display !== "none" ) {
                hideShortcuts();
            }
        } );
    }

    // =========================================================================
    // RESET POSITION
    // =========================================================================

    /**
     * Sets up the reset position button click handler.
     */
    function setupResetPosition() {
        document.getElementById( "btn-reset-position" ).addEventListener( "click", function() {
            callLua( "resetPosition" );
        } );
    }

    /** Updates zoom level display when view changes in Solar2D. */
    function onViewChanged( data ) {
        var el = document.getElementById( "zoom-level" );
        if ( el ) {
            el.textContent = Math.round( ( data.zoom || 1 ) * 100 ) + "%";
        }
    }

    /** Sets up the reset view button click handler. */
    function setupResetView() {
        var btn = document.getElementById( "btn-reset-view" );
        if ( !btn ) return;
        btn.addEventListener( "click", function() {
            callLua( "resetView" );
        } );
    }

    // =========================================================================
    // EXPORT
    // =========================================================================

    /**
     * Sets up all export button click handlers.
     */
    function setupExport() {
        document.getElementById( "btn-export-json" ).addEventListener( "click", exportCurrentJson );
        document.getElementById( "btn-export-png" ).addEventListener( "click", exportCurrentPng );
        document.getElementById( "btn-export-zip" ).addEventListener( "click", exportCurrentZip );
        document.getElementById( "btn-export-all-zip" ).addEventListener( "click", exportAllZip );
    }

    /**
     * Builds a clean export object from emitter data (strips internal fields).
     * @param {Object} data - Emitter data with params and name
     * @returns {Object} Clean export object
     */
    function buildExportObj( data ) {
        const exportObj = {};
        if ( data.params ) {
            for ( const key in data.params ) {
                exportObj[key] = data.params[key];
            }
        }
        if ( exportObj.textureFileName ) {
            exportObj.textureFileName = exportObj.textureFileName.replace( /^.*[\/\\]/, "" );
        }
        exportObj.name = data.name;
        return exportObj;
    }

    /**
     * Exports the selected emitter as a JSON file download.
     */
    function exportCurrentJson() {
        if ( !state.selectedObjectId || state.selectedObjectType !== TYPE_EMITTER ) return;

        callLuaAsync( "getExportData", state.selectedObjectId ).then( function( data ) {
            if ( !data ) return;

            const exportObj = buildExportObj( data );
            const jsonStr = JSON.stringify( exportObj, null, 2 );
            const blob = new Blob( [ jsonStr ], { type: "application/json" } );
            try {
                saveFile( blob, sanitizeFilename( data.name || "emitter" ) + ".json" );
                showToast( "Exported JSON: " + ( data.name || "emitter" ) );
            } catch ( err ) {
                showToast( "Export failed: " + err.message );
            }
        } ).catch( function( err ) {
            console.error( "Export JSON failed:", err );
            showToast( "Export failed" );
        } );
    }

    /**
     * Exports the selected emitter's texture as a PNG file download.
     */
    function exportCurrentPng() {
        if ( !state.selectedObjectId || state.selectedObjectType !== TYPE_EMITTER ) return;

        callLuaAsync( "getExportData", state.selectedObjectId, true ).then( function( data ) {
            if ( !data || !data.textureBase64 ) {
                showToast( "Texture data not available for export" );
                return;
            }

            const byteChars = atob( data.textureBase64 );
            const byteNumbers = new Array( byteChars.length );
            for ( let i = 0; i < byteChars.length; i++ ) {
                byteNumbers[i] = byteChars.charCodeAt( i );
            }
            const byteArray = new Uint8Array( byteNumbers );
            const blob = new Blob( [ byteArray ], { type: "image/png" } );
            try {
                saveFile( blob, sanitizeFilename( data.name || "texture" ) + ".png" );
                showToast( "Exported PNG: " + ( data.name || "texture" ) );
            } catch ( err ) {
                showToast( "Export failed: " + err.message );
            }
        } ).catch( function( err ) {
            console.error( "Export PNG failed:", err );
            showToast( "Export failed" );
        } );
    }

    /**
     * Exports the selected emitter as a ZIP file (JSON + PNG texture).
     */
    function exportCurrentZip() {
        if ( !state.selectedObjectId || state.selectedObjectType !== TYPE_EMITTER ) return;

        callLuaAsync( "getExportData", state.selectedObjectId, true ).then( function( data ) {
            if ( !data ) return;

            const zip = createZip();
            const name = sanitizeFilename( data.name || "emitter" );

            const exportObj = buildExportObj( data );
            zip.file( name + ".json", JSON.stringify( exportObj, null, 2 ) );

            if ( data.textureBase64 ) {
                const texName = ( data.textureFilename || "particle.png" ).replace( /^.*[\/\\]/, "" );
                zip.file( texName, data.textureBase64, { base64: true } );
            }

            zip.generateAsync( { type: "blob" } ).then( function( blob ) {
                try {
                    saveFile( blob, name + ".zip" );
                    showToast( "Exported ZIP: " + name );
                } catch ( err ) {
                    showToast( "Export failed: " + err.message );
                }
            } );
        } ).catch( function( err ) {
            console.error( "Export ZIP failed:", err );
            showToast( "Export failed" );
        } );
    }

    /**
     * Exports all emitters as a ZIP file.
     */
    function exportAllZip() {
        callLuaAsync( "getExportData", "all", true ).then( function( data ) {
            if ( !data || !data.length ) return;

            const zip = createZip();

            data.forEach( function( item ) {
                const name = sanitizeFilename( item.name || "emitter" );
                const folder = zip.folder( name );

                const exportObj = buildExportObj( item );
                folder.file( name + ".json", JSON.stringify( exportObj, null, 2 ) );

                if ( item.textureBase64 ) {
                    const texName = ( item.textureFilename || "particle.png" ).replace( /^.*[\/\\]/, "" );
                    folder.file( texName, item.textureBase64, { base64: true } );
                }
            } );

            zip.generateAsync( { type: "blob" } ).then( function( blob ) {
                try {
                    saveFile( blob, "all_emitters.zip" );
                    showToast( "Exported all emitters as ZIP" );
                } catch ( err ) {
                    showToast( "Export failed: " + err.message );
                }
            } );
        } ).catch( function( err ) {
            console.error( "Export All ZIP failed:", err );
            showToast( "Export failed" );
        } );
    }

    // =========================================================================
    // TEXTURE
    // =========================================================================

    var DEFAULT_TEXTURE = "assets/particles/basic_circle_01.png";

    /** Rebuilds the texture dropdown with preset and uploaded texture options. */
    function rebuildTextureDropdown() {
        const select = document.getElementById( "texture-preset" );
        if ( !select ) return;

        const currentValue = select.value;
        select.innerHTML = "";

        var presets = state.particlePresets || [];
        if ( presets.length > 0 ) {
            const presetGroup = document.createElement( "optgroup" );
            presetGroup.label = "Presets";
            presets.forEach( function( preset ) {
                const option = document.createElement( "option" );
                option.value = "assets/particles/" + preset.file;
                option.textContent = preset.label;
                presetGroup.appendChild( option );
            } );
            select.appendChild( presetGroup );
        }

        const uploadedNames = Object.keys( state.uploadedTextures ).sort();
        if ( uploadedNames.length > 0 ) {
            const uploadGroup = document.createElement( "optgroup" );
            uploadGroup.label = "Uploaded";
            uploadedNames.forEach( function( filename ) {
                const option = document.createElement( "option" );
                option.value = PREFIX_CUSTOM + filename;
                option.textContent = filename;
                uploadGroup.appendChild( option );
            } );
            select.appendChild( uploadGroup );
        }

        select.value = currentValue;
    }

    /** Updates the texture preview thumbnail with a data URL or asset path. */
    function updateTexturePreview( dataUrlOrPath ) {
        const img = document.getElementById( "texture-preview-img" );
        if ( !img ) return;

        if ( dataUrlOrPath && dataUrlOrPath.indexOf( "data:" ) === 0 ) {
            img.src = dataUrlOrPath;
        } else if ( dataUrlOrPath ) {
            img.src = "solar2d/src/" + dataUrlOrPath;
        } else {
            img.src = "";
        }
    }

    /** Syncs the texture dropdown, preview, and remove button with the active emitter's texture. */
    function updateTextureUI( textureInfo ) {
        if ( !textureInfo ) return;

        const select = document.getElementById( "texture-preset" );
        const removeBtn = document.getElementById( "btn-remove-texture" );

        if ( textureInfo.hasCustomTexture ) {
            const filename = textureInfo.textureFilename;

            if ( state.uploadedTextures[filename] ) {
                rebuildTextureDropdown();
            }

            if ( select ) {
                select.value = PREFIX_CUSTOM + filename;
            }
            if ( removeBtn ) removeBtn.style.display = "";

            const textureData = state.uploadedTextures[filename];
            if ( textureData ) {
                updateTexturePreview( textureData.dataUrl );
            }
        } else {
            if ( select ) {
                select.value = textureInfo.textureFileName;
            }
            if ( removeBtn ) removeBtn.style.display = "none";
            updateTexturePreview( textureInfo.textureFileName );
        }
    }

    /** Wires up the texture file upload input to send custom textures to Lua. */
    function setupTextureUpload() {
        const upload = document.getElementById( "texture-upload" );
        if ( !upload ) return;

        upload.addEventListener( "change", function() {
            const file = upload.files[0];
            if ( !file ) return;

            const reader = new FileReader();
            reader.onload = function( e ) {
                const dataUrl = e.target.result;
                const base64 = dataUrl.split( "," )[1];
                const filename = file.name;

                state.uploadedTextures[filename] = {
                    base64: base64,
                    dataUrl: dataUrl,
                };

                if ( state.selectedObjectId ) {
                    callLua( "setTexture", state.selectedObjectId, base64, filename );
                }

                rebuildTextureDropdown();
                const select = document.getElementById( "texture-preset" );
                if ( select ) {
                    select.value = PREFIX_CUSTOM + filename;
                }

                updateTexturePreview( dataUrl );

                const removeBtn = document.getElementById( "btn-remove-texture" );
                if ( removeBtn ) removeBtn.style.display = "";

                showToast( "Texture uploaded: " + filename );
            };
            reader.readAsDataURL( file );

            upload.value = "";
        } );
    }

    /** Handles texture dropdown changes, switching between preset and uploaded textures. */
    function setupTexturePresets() {
        const select = document.getElementById( "texture-preset" );
        if ( !select ) return;

        select.addEventListener( "change", function() {
            if ( !state.selectedObjectId ) return;

            const value = select.value;
            const removeBtn = document.getElementById( "btn-remove-texture" );

            if ( value.indexOf( PREFIX_CUSTOM ) === 0 ) {
                const filename = value.substring( PREFIX_CUSTOM.length );
                const textureData = state.uploadedTextures[filename];
                if ( textureData ) {
                    callLua( "setTexture", state.selectedObjectId, textureData.base64, filename );
                    updateTexturePreview( textureData.dataUrl );
                }
                if ( removeBtn ) removeBtn.style.display = "";
            } else {
                callLua( "setParam", state.selectedObjectId, "textureFileName", value );
                updateTexturePreview( value );
                if ( removeBtn ) removeBtn.style.display = "none";
            }
        } );
    }

    /** Wires up the remove-texture button to delete uploaded textures and revert to default. */
    function setupTextureRemove() {
        const removeBtn = document.getElementById( "btn-remove-texture" );
        if ( !removeBtn ) return;

        removeBtn.addEventListener( "click", function() {
            const select = document.getElementById( "texture-preset" );
            if ( !select ) return;

            const value = select.value;
            if ( value.indexOf( PREFIX_CUSTOM ) !== 0 ) {
                showToast( "Cannot remove preset textures" );
                return;
            }

            const filename = value.substring( PREFIX_CUSTOM.length );

            delete state.uploadedTextures[filename];

            if ( state.selectedObjectId ) {
                callLua( "setParam", state.selectedObjectId, "textureFileName", DEFAULT_TEXTURE );
            }

            rebuildTextureDropdown();
            select.value = DEFAULT_TEXTURE;
            updateTexturePreview( DEFAULT_TEXTURE );
            removeBtn.style.display = "none";

            showToast( "Removed texture: " + filename );
        } );
    }

    // =========================================================================
    // BACKGROUND COLOR & IMAGE
    // =========================================================================

    /** Sets the canvas container's CSS background to the given hex color. */
    function applyBackgroundColor( hexColor ) {
        const container = document.getElementById( "canvas-container" );
        if ( container ) {
            container.style.background = hexColor;
        }
    }

    /**
     * Re-encodes any image data URL as PNG via canvas before sending to
     * Solar2D's WASM runtime, which crashes on malformed PNG data.
     */
    function ensurePngDataUrl( dataUrl, callback ) {
        if ( !dataUrl ) return;
        var img = new Image();
        img.onload = function() {
            var canvas = document.createElement( "canvas" );
            canvas.width = img.naturalWidth;
            canvas.height = img.naturalHeight;
            var ctx = canvas.getContext( "2d" );
            ctx.drawImage( img, 0, 0 );
            callback( canvas.toDataURL( "image/png" ) );
        };
        img.onerror = function() {
            console.warn( "Failed to load/convert background image to PNG" );
        };
        img.src = dataUrl;
    }

    /** Sends the saved background color from localStorage to the Lua engine, CSS, and picker. */
    function restoreBackgroundToLua() {
        var savedColor = localStorage.getItem( "bg-color" ) || "#000000";
        var rgb = hexToRgb( savedColor );
        callLua( "setBackgroundColor", rgb.r, rgb.g, rgb.b );
        applyBackgroundColor( savedColor );
        var picker = document.getElementById( "bg-color-picker" );
        if ( picker ) picker.value = savedColor;
    }

    /** Initializes the background color picker and reset button, restoring saved color. */
    function setupBackgroundColor() {
        const picker = document.getElementById( "bg-color-picker" );
        const resetBtn = document.getElementById( "btn-bg-reset" );

        if ( !picker ) return;

        picker.addEventListener( "input", function() {
            const rgb = hexToRgb( picker.value );
            callLua( "setBackgroundColor", rgb.r, rgb.g, rgb.b );
            applyBackgroundColor( picker.value );
            localStorage.setItem( "bg-color", picker.value );
        } );

        if ( resetBtn ) {
            resetBtn.addEventListener( "click", function() {
                picker.value = "#000000";
                callLua( "setBackgroundColor", 0, 0, 0 );
                applyBackgroundColor( "#000000" );
                localStorage.setItem( "bg-color", "#000000" );
            } );
        }

        // Restore saved color on page load
        const savedColor = localStorage.getItem( "bg-color" ) || "#000000";
        picker.value = savedColor;
        applyBackgroundColor( savedColor );
    }

    // =========================================================================
    // GRID SIZE
    // =========================================================================

    /** Wires up the grid size slider, grid toggle, and emitter bounds dropdown. */
    function setupGuides() {
        const slider = document.getElementById( "grid-size-slider" );
        const number = document.getElementById( "grid-size-number" );
        if ( slider && number ) {
            slider.addEventListener( "input", function() {
                number.value = slider.value;
                callLua( "setGridSize", parseInt( slider.value, 10 ) );
            } );

            number.addEventListener( "change", function() {
                let val = parseInt( number.value, 10 );
                if ( val < 8 ) val = 8;
                if ( val > 128 ) val = 128;
                number.value = val;
                slider.value = val;
                callLua( "setGridSize", val );
            } );
        }

        var gridToggle = document.getElementById( "toggle-grid" );
        if ( gridToggle ) {
            var savedGrid = localStorage.getItem( "grid-visible" );
            if ( savedGrid !== null ) {
                gridToggle.checked = savedGrid === "true";
            }
            gridToggle.addEventListener( "change", function() {
                localStorage.setItem( "grid-visible", gridToggle.checked ? "true" : "false" );
                callLua( "setGridEnabled", gridToggle.checked );
            } );
        }

        var boundsSelect = document.getElementById( "emitter-bounds-mode" );
        if ( boundsSelect ) {
            var savedBounds = localStorage.getItem( "emitter-bounds-mode" );
            if ( savedBounds ) {
                boundsSelect.value = savedBounds;
            }
            boundsSelect.addEventListener( "change", function() {
                localStorage.setItem( "emitter-bounds-mode", boundsSelect.value );
                callLua( "setEmitterBoundsMode", boundsSelect.value );
            } );
        }

        // Grid color picker
        var gridColorPicker = document.getElementById( "grid-color-picker" );
        var gridColorReset = document.getElementById( "btn-grid-color-reset" );
        if ( gridColorPicker ) {
            var savedGridColor = localStorage.getItem( "grid-color" ) || "#333338";
            gridColorPicker.value = savedGridColor;

            gridColorPicker.addEventListener( "input", function() {
                var rgb = hexToRgb( gridColorPicker.value );
                callLua( "setGridColor", rgb.r, rgb.g, rgb.b );
                localStorage.setItem( "grid-color", gridColorPicker.value );
            } );
        }
        if ( gridColorReset ) {
            gridColorReset.addEventListener( "click", function() {
                var defaultColor = "#333338";
                if ( gridColorPicker ) gridColorPicker.value = defaultColor;
                var rgb = hexToRgb( defaultColor );
                callLua( "setGridColor", rgb.r, rgb.g, rgb.b );
                localStorage.setItem( "grid-color", defaultColor );
            } );
        }

        // Bounds color picker
        var boundsColorPicker = document.getElementById( "bounds-color-picker" );
        var boundsColorReset = document.getElementById( "btn-bounds-color-reset" );
        if ( boundsColorPicker ) {
            var savedBoundsColor = localStorage.getItem( "bounds-color" ) || "#ffffff";
            boundsColorPicker.value = savedBoundsColor;

            boundsColorPicker.addEventListener( "input", function() {
                var rgb = hexToRgb( boundsColorPicker.value );
                callLua( "setBoundsColor", rgb.r, rgb.g, rgb.b );
                localStorage.setItem( "bounds-color", boundsColorPicker.value );
            } );
        }
        if ( boundsColorReset ) {
            boundsColorReset.addEventListener( "click", function() {
                var defaultColor = "#ffffff";
                if ( boundsColorPicker ) boundsColorPicker.value = defaultColor;
                callLua( "setBoundsColor", 1, 1, 1 );
                localStorage.setItem( "bounds-color", defaultColor );
            } );
        }
    }

    // =========================================================================
    // CONTENT AREA CONTROL
    // =========================================================================

    /** Initializes Solar2D content area display. Inputs are disabled until dynamic resizing is implemented. */
    function setupContentArea() {
        var widthInput = document.getElementById( "canvas-width" );
        var heightInput = document.getElementById( "canvas-height" );
        var iframe = document.getElementById( "solar2d-iframe" );
        if ( !iframe ) return;

        // Fixed content area matching config.lua (960x640)
        var w = 960;
        var h = 640;
        if ( widthInput ) widthInput.value = w;
        if ( heightInput ) heightInput.value = h;
        iframe.classList.add( "fixed-size" );
        iframe.style.width = w + "px";
        iframe.style.height = h + "px";
    }

    // =========================================================================
    // UI SCALE CONTROL
    // =========================================================================

    /** Initializes the UI scale slider and applies the saved scale factor from localStorage. */
    function setupUIScale() {
        const slider = document.getElementById( "ui-scale-slider" );
        const valueDisplay = document.getElementById( "ui-scale-value" );

        if ( !slider ) return;

        const savedScale = localStorage.getItem( "ui-scale-factor" );
        var scale = savedScale ? parseFloat( savedScale ) : 1.2;
        if ( scale < 1.0 ) scale = 1.0;
        if ( scale > 2.0 ) scale = 2.0;
        slider.value = scale;
        document.documentElement.style.setProperty( "--scale-factor", scale );
        if ( valueDisplay ) {
            valueDisplay.textContent = Math.round( scale * 100 ) + "%";
        }

        slider.addEventListener( "input", function() {
            const scale = parseFloat( slider.value );
            document.documentElement.style.setProperty( "--scale-factor", scale );
            if ( valueDisplay ) {
                valueDisplay.textContent = Math.round( scale * 100 ) + "%";
            }
            localStorage.setItem( "ui-scale-factor", scale );
        } );
    }

    // =========================================================================
    // PLAYBACK CONTROLS
    // =========================================================================

    /** Wires up the pause, play, and restart buttons for emitter playback. */
    function setupPlaybackControls() {
        const btnPause = document.getElementById( "btn-pause" );
        const btnPlay = document.getElementById( "btn-play" );
        const btnRestart = document.getElementById( "btn-restart" );
        if ( !btnPause || !btnPlay || !btnRestart ) return;

        btnPause.addEventListener( "click", function() {
            callLua( "pauseEmitters" );
            btnPause.style.display = "none";
            btnPlay.style.display = "";
        } );

        btnPlay.addEventListener( "click", function() {
            callLua( "resumeEmitters" );
            btnPlay.style.display = "none";
            btnPause.style.display = "";
        } );

        btnRestart.addEventListener( "click", function() {
            callLua( "restartEmitters" );
            btnPlay.style.display = "none";
            btnPause.style.display = "";
        } );
    }


    // =========================================================================
    // IFRAME LOADING & HANDSHAKE
    // =========================================================================

    /** Creates the loading overlay and signals the iframe once the Solar2D engine loads. */
    function setupIframeLoading() {
        const iframe = document.getElementById( "solar2d-iframe" );
        const container = document.getElementById( "canvas-container" );
        if ( !iframe || !container ) return;

        const overlay = document.createElement( "div" );
        overlay.id = "iframe-loading-overlay";
        overlay.innerHTML = '<div class="loading-spinner"></div><p>Loading Solar2D engine...</p>';
        container.appendChild( overlay );

        iframe.addEventListener( "load", function() {
            // Brief delay for the Solar2D JS bridge to initialize inside the iframe
            setTimeout( function() {
                callLua( "parentReady" );
            }, 50 );
        } );

        const loadTimeout = setTimeout( function() {
            const spinner = overlay.querySelector( ".loading-spinner" );
            if ( spinner ) spinner.style.display = "none";
            const msg = overlay.querySelector( "p" );
            if ( msg ) {
                msg.textContent = "Failed to load Solar2D engine. Check that solar2d/bin/ contains the build files.";
                msg.style.color = "#ff6666";
            }
        }, 10000 );

        state._loadTimeout = loadTimeout;
    }

    /** Removes the loading overlay and clears the load timeout. */
    function hideIframeLoading() {
        const overlay = document.getElementById( "iframe-loading-overlay" );
        if ( overlay && overlay.parentNode ) {
            overlay.parentNode.removeChild( overlay );
        }
        if ( state._loadTimeout ) {
            clearTimeout( state._loadTimeout );
            state._loadTimeout = null;
        }
    }

    // =========================================================================
    // SCENES
    // =========================================================================

    var SCENE_PRESETS = {};

    var SCENE_PRESET_FILES = [
        { key: "fantasy", url: "solar2d/src/assets/scenes/fantasy.json" },
        { key: "snow", url: "solar2d/src/assets/scenes/snow.json" },
        { key: "detective", url: "solar2d/src/assets/scenes/detective.json" },
        { key: "scifi", url: "solar2d/src/assets/scenes/scifi.json" },
    ];

    /** Loads all scene preset JSON files and populates SCENE_PRESETS. */
    function loadScenePresets() {
        var loaded = 0;
        SCENE_PRESET_FILES.forEach( function( entry ) {
            var xhr = new XMLHttpRequest();
            xhr.open( "GET", entry.url, true );
            xhr.onload = function() {
                if ( xhr.status === 200 ) {
                    try {
                        SCENE_PRESETS[entry.key] = JSON.parse( xhr.responseText );
                    } catch ( e ) {
                        console.error( "Failed to parse scene preset: " + entry.url, e );
                    }
                } else {
                    console.error( "Failed to load scene preset: " + entry.url + " (status " + xhr.status + ")" );
                }
                loaded++;
                if ( loaded === SCENE_PRESET_FILES.length ) {
                    rebuildSceneDropdown();
                }
            };
            xhr.onerror = function() {
                console.error( "Network error loading scene preset: " + entry.url );
                loaded++;
                if ( loaded === SCENE_PRESET_FILES.length ) {
                    rebuildSceneDropdown();
                }
            };
            xhr.send();
        } );
    }

    /** Initializes scene load/save/delete buttons and the scene dropdown. */
    function setupScenes() {
        loadScenePresets();
        rebuildSceneDropdown();

        var loadBtn = document.getElementById( "btn-load-scene" );
        var saveBtn = document.getElementById( "btn-save-scene" );
        var deleteBtn = document.getElementById( "btn-delete-scene" );
        var select = document.getElementById( "scene-select" );

        if ( loadBtn ) {
            loadBtn.addEventListener( "click", function() {
                var value = select ? select.value : "";
                if ( !value ) {
                    showToast( "Select a scene first" );
                    return;
                }
                if ( value.indexOf( PREFIX_PRESET ) === 0 ) {
                    var presetId = value.substring( PREFIX_PRESET.length );
                    loadPresetScene( presetId );
                } else if ( value.indexOf( PREFIX_CUSTOM ) === 0 ) {
                    var sceneName = value.substring( PREFIX_CUSTOM.length );
                    loadCustomScene( sceneName );
                }
            } );
        }

        if ( saveBtn ) {
            saveBtn.addEventListener( "click", function() {
                var name = prompt( "Scene name:" );
                if ( !name || !name.trim() ) return;
                name = name.trim();
                saveCustomScene( name );
            } );
        }

        if ( deleteBtn ) {
            deleteBtn.addEventListener( "click", function() {
                var value = select ? select.value : "";
                if ( value.indexOf( PREFIX_CUSTOM ) !== 0 ) {
                    showToast( "Cannot delete preset scenes" );
                    return;
                }
                var sceneName = value.substring( PREFIX_CUSTOM.length );
                if ( !confirm( "Delete scene \"" + sceneName + "\"?" ) ) return;
                deleteCustomScene( sceneName );
            } );
        }

        if ( select ) {
            select.addEventListener( "change", function() {
                var value = select.value;
                var isCustom = value.indexOf( PREFIX_CUSTOM ) === 0;
                if ( deleteBtn ) deleteBtn.disabled = !isCustom;
                if ( loadBtn ) loadBtn.disabled = !value;
            } );
        }

        if ( deleteBtn ) deleteBtn.disabled = true;
        if ( loadBtn ) loadBtn.disabled = true;
    }

    /** Rebuilds the scene dropdown with preset and saved custom scenes. */
    function rebuildSceneDropdown() {
        var select = document.getElementById( "scene-select" );
        if ( !select ) return;

        var currentValue = select.value;
        select.innerHTML = '<option value="">-- Select Scene --</option>';

        // Preset scenes
        var presetGroup = document.createElement( "optgroup" );
        presetGroup.label = "Presets";
        for ( var key in SCENE_PRESETS ) {
            var option = document.createElement( "option" );
            option.value = PREFIX_PRESET + key;
            option.textContent = SCENE_PRESETS[key].name;
            presetGroup.appendChild( option );
        }
        select.appendChild( presetGroup );

        // Custom scenes
        var customScenes = getCustomScenes();
        var customNames = Object.keys( customScenes ).sort();
        if ( customNames.length > 0 ) {
            var customGroup = document.createElement( "optgroup" );
            customGroup.label = "Saved Scenes";
            customNames.forEach( function( name ) {
                var option = document.createElement( "option" );
                option.value = PREFIX_CUSTOM + name;
                option.textContent = name;
                customGroup.appendChild( option );
            } );
            select.appendChild( customGroup );
        }

        select.value = currentValue;
    }

    /** Reads saved custom scenes from localStorage, returning an object keyed by name. */
    function getCustomScenes() {
        try {
            var data = localStorage.getItem( SCENES_STORAGE_KEY );
            return data ? JSON.parse( data ) : {};
        } catch ( e ) {
            return {};
        }
    }

    /** Persists the custom scenes object to localStorage, handling quota errors. */
    function saveCustomScenes( scenes ) {
        try {
            localStorage.setItem( SCENES_STORAGE_KEY, JSON.stringify( scenes ) );
        } catch ( e ) {
            if ( e.name === "QuotaExceededError" || e.code === 22 ) {
                showToast( "Storage full — cannot save scene. Try deleting old scenes." );
            } else {
                showToast( "Failed to save scene" );
            }
        }
    }

    /** Returns a Promise that resolves after the given number of milliseconds. */
    function delay( ms ) {
        return new Promise( function( resolve ) { setTimeout( resolve, ms ); } );
    }

    /** Sets the background color in Lua, CSS, localStorage, and the color picker. */
    function applySceneBackground( bgColor ) {
        var rgb = hexToRgb( bgColor );
        callLua( "setBackgroundColor", rgb.r, rgb.g, rgb.b );
        applyBackgroundColor( bgColor );
        localStorage.setItem( "bg-color", bgColor );
        var picker = document.getElementById( "bg-color-picker" );
        if ( picker ) picker.value = bgColor;
    }

    /** Sends position, scale, and opacity properties to Lua for the selected image. */
    function applyImageProperties( def ) {
        if ( !state.selectedObjectId || state.selectedObjectType !== TYPE_IMAGE ) return;
        if ( def.x != null ) callLua( "setImageProperty", state.selectedObjectId, "x", def.x );
        if ( def.y != null ) callLua( "setImageProperty", state.selectedObjectId, "y", def.y );
        if ( def.scale != null ) callLua( "setImageProperty", state.selectedObjectId, "scale", def.scale );
        if ( def.opacity != null ) callLua( "setImageProperty", state.selectedObjectId, "opacity", def.opacity );
    }

    /** Extracts and clamps emitter parameters from a saved data object, skipping metadata keys. */
    function extractEmitterParams( src ) {
        _suppressClampToast = true;
        var params = {};
        for ( var key in src ) {
            if ( !src.hasOwnProperty( key ) ) continue;
            if ( key === "name" || key === "id" || key === "textureBase64" || key === "textureFilename" ) continue;
            if ( key === "duration" ) {
                var dur = parseFloat( src[key] );
                params[key] = ( isNaN( dur ) || dur <= 0 ) ? -1 : Math.min( dur, 30 );
            } else if ( PARAM_RANGES[key] ) {
                params[key] = clampParam( key, src[key] );
            } else {
                params[key] = src[key];
            }
        }
        _suppressClampToast = false;
        return params;
    }

    /** Re-registers a custom texture from saved emitter data and applies it in Lua. */
    function restoreEmitterTexture( emitterData ) {
        if ( !emitterData.textureBase64 || !emitterData.textureFilename ) return;
        state.uploadedTextures[emitterData.textureFilename] = {
            base64: emitterData.textureBase64,
            dataUrl: "data:image/png;base64," + emitterData.textureBase64,
        };
        callLua( "setTexture", state.selectedObjectId, emitterData.textureBase64, emitterData.textureFilename );
    }

    /** Loads a preset background image by filename, converts to data URL, and creates it in Lua. */
    function loadScenePresetImage( def ) {
        return new Promise( function( resolve ) {
            var imageUrl = "solar2d/src/assets/images/" + def.presetFile;
            var img = new Image();
            img.onload = function() {
                var canvas = document.createElement( "canvas" );
                canvas.width = img.naturalWidth;
                canvas.height = img.naturalHeight;
                canvas.getContext( "2d" ).drawImage( img, 0, 0 );
                var dataUrl = canvas.toDataURL( "image/png" );
                callLua( "createImage", dataUrl, def.presetFile, def.name, img.naturalWidth, img.naturalHeight );
                setTimeout( function() {
                    applyImageProperties( def );
                    resolve();
                }, 50 );
            };
            img.onerror = function() { resolve(); };
            img.src = imageUrl;
        } );
    }

    /** Creates an image in Lua from saved base64 data and applies its properties. */
    function loadSavedImage( def ) {
        return new Promise( function( resolve ) {
            callLua( "createImage", def.imageBase64, def.filename || "image.png", def.name || "Image", def.width || 100, def.height || 100 );
            setTimeout( function() {
                applyImageProperties( def );
                resolve();
            }, 50 );
        } );
    }

    /** Creates an emitter from a template ID in Lua and applies name/position overrides. */
    function loadPresetEmitter( def ) {
        return new Promise( function( resolve ) {
            callLua( "createEmitter", def.templateId );
            setTimeout( function() {
                if ( state.selectedObjectId && state.selectedObjectType === TYPE_EMITTER ) {
                    if ( def.name ) callLua( "renameObject", state.selectedObjectId, def.name, TYPE_EMITTER );
                    if ( def.x != null && def.y != null ) {
                        callLua( "setEmitterPosition", state.selectedObjectId, def.x, def.y );
                    }
                }
                resolve();
            }, 50 );
        } );
    }

    /** Creates an emitter in Lua from saved parameter data and restores its custom texture. */
    function loadSavedEmitter( def ) {
        var paramSource = def.params || def;
        var params = extractEmitterParams( paramSource );
        return new Promise( function( resolve ) {
            callLua( "createEmitter" );
            setTimeout( function() {
                if ( state.selectedObjectId ) {
                    callLua( "setParams", state.selectedObjectId, params );
                    if ( def.name ) callLua( "renameObject", state.selectedObjectId, def.name, TYPE_EMITTER );
                    if ( def.x != null && def.y != null ) {
                        callLua( "setEmitterPosition", state.selectedObjectId, def.x, def.y );
                    }
                    restoreEmitterTexture( def );
                }
                resolve();
            }, 50 );
        } );
    }

    /** Sequentially loads all objects defined in a scene config, respecting order for z-layering. */
    async function loadSceneObjects( config ) {
        // If the scene defines a unified objects array, use it for ordered loading.
        // This allows interleaving images and emitters for precise z-order control.
        if ( config.objects && config.objects.length > 0 ) {
            for ( var i = 0; i < config.objects.length; i++ ) {
                var obj = config.objects[i];
                if ( obj.type === "image" ) {
                    if ( obj.presetFile ) {
                        await loadScenePresetImage( obj );
                    } else {
                        await loadSavedImage( obj );
                    }
                } else if ( obj.type === "emitter" ) {
                    if ( obj.templateId ) {
                        await loadPresetEmitter( obj );
                    } else {
                        await loadSavedEmitter( obj );
                    }
                }
                await delay( 100 );
            }
        } else {
            // Fallback: load all images first, then all emitters (legacy behavior)
            var imageList = config.images || [];
            var emitterList = config.emitters || [];

            for ( var i = 0; i < imageList.length; i++ ) {
                var imgDef = imageList[i];
                if ( imgDef.presetFile ) {
                    await loadScenePresetImage( imgDef );
                } else {
                    await loadSavedImage( imgDef );
                }
                await delay( 100 );
            }

            for ( var j = 0; j < emitterList.length; j++ ) {
                var emDef = emitterList[j];
                if ( emDef.templateId ) {
                    await loadPresetEmitter( emDef );
                } else {
                    await loadSavedEmitter( emDef );
                }
                await delay( 100 );
            }
        }

        rebuildTextureDropdown();
    }

    /** Clears all objects and loads a built-in preset scene by ID. */
    function loadPresetScene( presetId ) {
        var preset = SCENE_PRESETS[presetId];
        if ( !preset ) {
            showToast( "Unknown preset" );
            return;
        }

        if ( !confirm( "Loading a scene will replace all current objects. Continue?" ) ) return;

        callLua( "clearAllObjects" );
        applySceneBackground( preset.backgroundColor || "#000000" );

        loadSceneObjects( preset ).then( function() {
            showToast( "Loaded scene: " + preset.name );
        } );
    }

    /** Captures the current scene state from Lua and saves it to localStorage under the given name. */
    function saveCustomScene( name ) {
        callLuaAsync( "getSceneData" ).then( function( data ) {
            if ( !data ) {
                showToast( "No scene data to save" );
                return;
            }

            var scene = {
                name: name,
                timestamp: Date.now(),
                backgroundColor: localStorage.getItem( "bg-color" ) || "#000000",
                objects: data.objects || [],
            };

            var scenes = getCustomScenes();
            scenes[name] = scene;
            saveCustomScenes( scenes );
            rebuildSceneDropdown();

            var select = document.getElementById( "scene-select" );
            if ( select ) select.value = PREFIX_CUSTOM + name;

            showToast( "Scene saved: " + name );
        } ).catch( function( err ) {
            console.error( "Save scene failed:", err );
            showToast( "Failed to save scene" );
        } );
    }

    /** Clears all objects and loads a user-saved scene from localStorage. */
    function loadCustomScene( sceneName ) {
        var scenes = getCustomScenes();
        var scene = scenes[sceneName];
        if ( !scene ) {
            showToast( "Scene not found" );
            return;
        }

        if ( !confirm( "Loading a scene will replace all current objects. Continue?" ) ) return;

        callLua( "clearAllObjects" );
        applySceneBackground( scene.backgroundColor || "#000000" );

        loadSceneObjects( scene ).then( function() {
            showToast( "Loaded scene: " + sceneName );
        } );
    }

    /** Deletes a custom scene from localStorage and refreshes the dropdown. */
    function deleteCustomScene( sceneName ) {
        var scenes = getCustomScenes();
        delete scenes[sceneName];
        saveCustomScenes( scenes );
        rebuildSceneDropdown();
        showToast( "Scene deleted: " + sceneName );
    }

    // =========================================================================
    // LOCAL STORAGE AUTO-SAVE
    // =========================================================================

    var _autosaveIntervalId = null;

    /** Starts the periodic auto-save timer that captures scene data to localStorage. */
    function setupAutoSave() {
        var toggle = document.getElementById( "toggle-autosave" );

        var savedPref = localStorage.getItem( "autosave-enabled" );
        var enabled = savedPref !== "false";

        if ( toggle ) {
            toggle.checked = enabled;
        }

        function startAutosave() {
            if ( _autosaveIntervalId ) return;
            _autosaveIntervalId = setInterval( function() {
                if ( state.objects.length === 0 ) return;

                callLuaAsync( "getSceneData" ).then( function( data ) {
                    if ( !data ) return;

                    var saveData = {
                        version: 3,
                        timestamp: Date.now(),
                        objects: data.objects || [],
                        backgroundColor: localStorage.getItem( "bg-color" ) || "#000000",
                    };
                    try {
                        localStorage.setItem( STORAGE_KEY, JSON.stringify( saveData ) );
                    } catch ( e ) {
                        if ( e.name === "QuotaExceededError" || e.code === 22 ) {
                            showToast( "Storage full — autosave failed. Try clearing old scenes." );
                        }
                    }
                } ).catch( function( err ) {
                    console.warn( "Autosave failed:", err );
                } );
            }, AUTOSAVE_INTERVAL );
        }

        function stopAutosave() {
            if ( _autosaveIntervalId ) {
                clearInterval( _autosaveIntervalId );
                _autosaveIntervalId = null;
            }
        }

        if ( enabled ) {
            startAutosave();
        }

        if ( toggle ) {
            toggle.addEventListener( "change", function() {
                var isEnabled = toggle.checked;
                localStorage.setItem( "autosave-enabled", isEnabled ? "true" : "false" );
                if ( isEnabled ) {
                    startAutosave();
                } else {
                    stopAutosave();
                }
            } );
        }
    }

    // =========================================================================
    // CLEAR LOCAL STORAGE
    // =========================================================================

    /** Wires up the clear scene button to remove all emitters and images. */
    function setupClearScene() {
        var btn = document.getElementById( "btn-clear-scene" );
        if ( !btn ) return;

        btn.addEventListener( "click", function() {
            if ( !state.objects || state.objects.length === 0 ) {
                showToast( "Scene is already empty" );
                return;
            }
            if ( !confirm( "Clear scene? This will remove all emitters and images." ) ) return;

            state.objects.slice().forEach( function( obj ) {
                if ( obj.type === TYPE_IMAGE ) {
                    callLua( "removeImage", obj.id );
                } else {
                    callLua( "removeEmitter", obj.id );
                }
            } );
            showToast( "Scene cleared" );
        } );
    }

    /** Wires up the clear storage button with a confirmation modal. */
    function setupClearStorage() {
        var btn = document.getElementById( "btn-clear-storage" );
        var overlay = document.getElementById( "confirm-clear-overlay" );
        var btnConfirm = document.getElementById( "btn-confirm-clear" );
        var btnCancel = document.getElementById( "btn-cancel-clear" );
        if ( !btn || !overlay || !btnConfirm || !btnCancel ) return;

        btn.addEventListener( "click", function() {
            overlay.style.display = "";
        } );

        btnCancel.addEventListener( "click", function() {
            overlay.style.display = "none";
        } );

        overlay.addEventListener( "click", function( e ) {
            if ( e.target === overlay ) {
                overlay.style.display = "none";
            }
        } );

        document.addEventListener( "keydown", function( e ) {
            if ( e.key === "Escape" && overlay.style.display !== "none" ) {
                overlay.style.display = "none";
            }
        } );

        btnConfirm.addEventListener( "click", function() {
            localStorage.clear();
            location.reload();
        } );
    }

    /** Checks localStorage for a previous session and prompts the user to restore it. */
    function checkAutoRestore() {
        try {
            var saved = localStorage.getItem( STORAGE_KEY );
            if ( !saved ) return;

            var saveData = JSON.parse( saved );
            if ( !saveData ) return;

            // Support v1 (just emitters array), v2 (emitters + images), v3 (unified objects)
            var totalCount = 0;
            if ( saveData.objects && saveData.objects.length ) {
                totalCount = saveData.objects.length;
            } else {
                totalCount = ( ( saveData.emitters && saveData.emitters.length ) || 0 )
                    + ( ( saveData.images && saveData.images.length ) || 0 );
            }
            if ( totalCount === 0 ) return;

            var age = Date.now() - ( saveData.timestamp || 0 );
            var TWO_DAYS = 48 * 60 * 60 * 1000;
            if ( age > TWO_DAYS ) {
                localStorage.removeItem( STORAGE_KEY );
                return;
            }

            var minutes = Math.round( age / 60000 );
            var hours = Math.floor( age / 3600000 );
            var timeLabel;
            if ( hours >= 24 ) {
                timeLabel = "yesterday";
            } else if ( hours >= 1 ) {
                timeLabel = hours + " hour" + ( hours !== 1 ? "s" : "" );
            } else if ( minutes < 1 ) {
                timeLabel = "less than a minute";
            } else {
                timeLabel = minutes + " minute" + ( minutes !== 1 ? "s" : "" );
            }

            var desc = totalCount + " object" + ( totalCount !== 1 ? "s" : "" );
            if ( confirm( "Restore previous session from " + timeLabel + " ago? (" + desc + ")" ) ) {
                callLua( "skipDefaultEmitter" );
                state._pendingRestore = saveData;
                if ( saveData.backgroundColor ) {
                    localStorage.setItem( "bg-color", saveData.backgroundColor );
                }
            } else {
                localStorage.removeItem( STORAGE_KEY );
            }
        } catch ( e ) {
            console.warn( "Auto-restore check failed:", e );
        }
    }

    /** Applies the pending restore data (if any) by clearing objects and loading the saved scene. */
    function applyPendingRestore() {
        if ( !state._pendingRestore ) return;

        var restoreData = state._pendingRestore;
        state._pendingRestore = null;

        // Support v1 (array of emitters), v2 (emitters + images), v3 (unified objects)
        var sceneConfig;
        if ( Array.isArray( restoreData ) ) {
            sceneConfig = { emitters: restoreData, images: [] };
        } else if ( restoreData.objects && restoreData.objects.length ) {
            sceneConfig = { objects: restoreData.objects };
        } else {
            sceneConfig = { emitters: restoreData.emitters || [], images: restoreData.images || [] };
        }

        // Clear existing objects
        if ( state.objects && state.objects.length > 0 ) {
            state.objects.forEach( function( obj ) {
                if ( obj.type === TYPE_IMAGE ) {
                    callLua( "removeImage", obj.id );
                } else {
                    callLua( "removeEmitter", obj.id );
                }
            } );
        }

        var totalCount = sceneConfig.objects ? sceneConfig.objects.length : ( sceneConfig.emitters.length + sceneConfig.images.length );
        loadSceneObjects( sceneConfig ).then( function() {
            showToast( "Session restored (" + totalCount + " object" + ( totalCount !== 1 ? "s" : "" ) + ")" );
        } );
    }

    // =========================================================================
    // UTILITIES
    // =========================================================================

    /** Converts a hex color string to an object with r, g, b values normalized to 0-1. */
    function hexToRgb( hex ) {
        const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec( hex );
        return result ? {
            r: parseInt( result[1], 16 ) / 255,
            g: parseInt( result[2], 16 ) / 255,
            b: parseInt( result[3], 16 ) / 255,
        } : { r: 0, g: 0, b: 0 };
    }

    /** Converts normalized 0-1 RGB values to a hex color string (e.g. "#ff8800"). */
    function rgbToHex( r, g, b ) {
        const toHex = function( c ) {
            const hex = Math.round( Math.max( 0, Math.min( 1, c ) ) * 255 ).toString( 16 );
            return hex.length === 1 ? "0" + hex : hex;
        };
        return "#" + toHex( r ) + toHex( g ) + toHex( b );
    }

    /** Replaces non-alphanumeric characters (except hyphens and underscores) with underscores. */
    function sanitizeFilename( name ) {
        return name.replace( /[^a-zA-Z0-9_\-]/g, "_" );
    }

    /** Triggers a browser file download for the given Blob with the specified filename. */
    function saveFile( blob, filename ) {
        var url = URL.createObjectURL( blob );
        var a = document.createElement( "a" );
        a.href = url;
        a.download = filename;
        document.body.appendChild( a );
        a.click();
        setTimeout( function() {
            document.body.removeChild( a );
            URL.revokeObjectURL( url );
        }, 100 );
    }

    // =========================================================================
    // INLINE ZIP CREATOR
    // =========================================================================

    var crc32Table = ( function() {
        var table = new Uint32Array( 256 );
        for ( var i = 0; i < 256; i++ ) {
            var c = i;
            for ( var j = 0; j < 8; j++ ) {
                c = ( c & 1 ) ? ( 0xEDB88320 ^ ( c >>> 1 ) ) : ( c >>> 1 );
            }
            table[i] = c;
        }
        return table;
    } )();

    /** Computes a CRC-32 checksum for a Uint8Array. */
    function crc32( data ) {
        var crc = 0xFFFFFFFF;
        for ( var i = 0; i < data.length; i++ ) {
            crc = crc32Table[( crc ^ data[i] ) & 0xFF] ^ ( crc >>> 8 );
        }
        return ( crc ^ 0xFFFFFFFF ) >>> 0;
    }

    /** Decodes a base64 string into a Uint8Array. */
    function base64ToUint8Array( base64 ) {
        var raw = atob( base64 );
        var arr = new Uint8Array( raw.length );
        for ( var i = 0; i < raw.length; i++ ) {
            arr[i] = raw.charCodeAt( i );
        }
        return arr;
    }

    /** Builds an uncompressed (STORE method) ZIP file Blob from an array of {name, data} entries. */
    function buildZipBlob( files ) {
        var localSize = 0;
        var centralSize = 0;
        for ( var i = 0; i < files.length; i++ ) {
            var nameBytes = new TextEncoder().encode( files[i].name );
            files[i].nameBytes = nameBytes;
            files[i].crc = crc32( files[i].data );
            localSize += 30 + nameBytes.length + files[i].data.length;
            centralSize += 46 + nameBytes.length;
        }
        var totalSize = localSize + centralSize + 22;
        var buf = new Uint8Array( totalSize );
        var view = new DataView( buf.buffer );
        var offset = 0;
        var offsets = [];

        // Write local file headers + data
        for ( var i = 0; i < files.length; i++ ) {
            var f = files[i];
            offsets.push( offset );
            view.setUint32( offset, 0x04034B50, true );       // Local file header signature
            view.setUint16( offset + 4, 20, true );           // Version needed (2.0)
            view.setUint16( offset + 6, 0, true );            // Flags
            view.setUint16( offset + 8, 0, true );            // Compression (STORE)
            view.setUint16( offset + 10, 0, true );           // Mod time
            view.setUint16( offset + 12, 0, true );           // Mod date
            view.setUint32( offset + 14, f.crc, true );       // CRC-32
            view.setUint32( offset + 18, f.data.length, true ); // Compressed size
            view.setUint32( offset + 22, f.data.length, true ); // Uncompressed size
            view.setUint16( offset + 26, f.nameBytes.length, true ); // Filename length
            view.setUint16( offset + 28, 0, true );           // Extra field length
            buf.set( f.nameBytes, offset + 30 );
            buf.set( f.data, offset + 30 + f.nameBytes.length );
            offset += 30 + f.nameBytes.length + f.data.length;
        }

        // Write central directory
        var cdOffset = offset;
        for ( var i = 0; i < files.length; i++ ) {
            var f = files[i];
            view.setUint32( offset, 0x02014B50, true );       // Central directory signature
            view.setUint16( offset + 4, 20, true );           // Version made by
            view.setUint16( offset + 6, 20, true );           // Version needed
            view.setUint16( offset + 8, 0, true );            // Flags
            view.setUint16( offset + 10, 0, true );           // Compression (STORE)
            view.setUint16( offset + 12, 0, true );           // Mod time
            view.setUint16( offset + 14, 0, true );           // Mod date
            view.setUint32( offset + 16, f.crc, true );       // CRC-32
            view.setUint32( offset + 20, f.data.length, true ); // Compressed size
            view.setUint32( offset + 24, f.data.length, true ); // Uncompressed size
            view.setUint16( offset + 28, f.nameBytes.length, true ); // Filename length
            view.setUint16( offset + 30, 0, true );           // Extra field length
            view.setUint16( offset + 32, 0, true );           // File comment length
            view.setUint16( offset + 34, 0, true );           // Disk number start
            view.setUint16( offset + 36, 0, true );           // Internal attributes
            view.setUint32( offset + 38, 0, true );           // External attributes
            view.setUint32( offset + 42, offsets[i], true );   // Local header offset
            buf.set( f.nameBytes, offset + 46 );
            offset += 46 + f.nameBytes.length;
        }

        // End of central directory record
        var cdSize = offset - cdOffset;
        view.setUint32( offset, 0x06054B50, true );           // EOCD signature
        view.setUint16( offset + 4, 0, true );                // Disk number
        view.setUint16( offset + 6, 0, true );                // CD start disk
        view.setUint16( offset + 8, files.length, true );     // CD entries (this disk)
        view.setUint16( offset + 10, files.length, true );    // CD entries (total)
        view.setUint32( offset + 12, cdSize, true );          // CD size
        view.setUint32( offset + 16, cdOffset, true );        // CD offset
        view.setUint16( offset + 20, 0, true );               // Comment length

        return new Blob( [ buf ], { type: "application/zip" } );
    }

    /** Creates a lightweight ZIP builder with file(), folder(), and generateAsync() methods. */
    function createZip() {
        var files = [];

        var zipObj = {
            file: function( name, content, options ) {
                var data;
                if ( options && options.base64 ) {
                    data = base64ToUint8Array( content );
                } else {
                    data = new TextEncoder().encode( content );
                }
                files.push( { name: name, data: data } );
                return zipObj;
            },
            folder: function( folderName ) {
                return {
                    file: function( name, content, options ) {
                        return zipObj.file( folderName + "/" + name, content, options );
                    }
                };
            },
            generateAsync: function() {
                return Promise.resolve( buildZipBlob( files ) );
            }
        };

        return zipObj;
    }

} )();
