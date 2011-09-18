/*
Copyright 2011 Pedro Casaubon

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package es.xperiments.media
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.FocusEvent;
	import flash.events.LocationChangeEvent;
	import flash.filesystem.File;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.media.StageWebView;
	import flash.system.System;

	public class StageWebViewBridge extends Bitmap
	{
		private static const _zeroPoint : Point = new Point( 0, 0 );
		private static var _translatedPoint : Point;
		private var _bridge : StageWebViewBridgeExternal;
		private var _view : StageWebView;
		private var _viewPort : Rectangle;
		private var _tmpFile : File = new File();
		private var _snapShotVisible : Boolean = false;
		private var _getSnapShotCallBack : Function;

		/**
		 * @param xpos Indicates the initial x pos
		 * @param ypos Indicates the initial y pos
		 * @param w Indicates the initial width
		 * @param h Indicates the initial height
		 * 
		 * @example
		 *  var testBridge:StageWebViewBridge = new StageWebViewBridge( );
		 * 
		 */
		public function StageWebViewBridge( xpos : uint = 0, ypos : uint = 0, w : uint = 400, h : uint = 400 )
		{
			_viewPort = new Rectangle( 0, 0, w, h );
			_view = new StageWebView();
			_view.viewPort = _viewPort;

			_bridge = new StageWebViewBridgeExternal( this );

			// adds callback to get Root Ptah from JS
			_bridge.addCallback( 'getRootPath', StageWebViewDisk.getRootPath );

			_view.addEventListener( Event.COMPLETE, onListener );
			_view.addEventListener( ErrorEvent.ERROR, onListener );
			_view.addEventListener( FocusEvent.FOCUS_IN, onListener );
			_view.addEventListener( FocusEvent.FOCUS_OUT, onListener );
			_view.addEventListener( LocationChangeEvent.LOCATION_CHANGE, onListener );
			_view.addEventListener( LocationChangeEvent.LOCATION_CHANGING, onListener );

			x = xpos;
			y = ypos;
			setSize( w, h );
			cacheAsBitmap = true;
			cacheAsBitmapMatrix = transform.concatenatedMatrix;
			addEventListener( Event.ADDED_TO_STAGE, onAdded );
		}

		/**
		 * On added to stage, initialize "real" position with
		 * localToGlobal and asign the new viewport
		 */
		private function onAdded( event : Event ) : void
		{
			if ( visible ) _view.stage = stage;
			_translatedPoint = localToGlobal( _zeroPoint );
			_viewPort.x = _translatedPoint.x;
			_viewPort.y = _translatedPoint.y;
			viewPort = _viewPort;
		}

		/**
		 * Generic StageWebView Listener. Controls LOCATION_CHANGING events for catching incomming data.
		 */
		private function onListener( e : Event ) : void
		{
			switch( true )
			{
				case e.type == Event.COMPLETE:
					_bridge.initJavascriptCommunication();
					dispatchEvent( e );
					break;
				case e.type == LocationChangeEvent.LOCATION_CHANGING:
					var currLocation : String = unescape( (e as LocationChangeEvent).location );
					switch( true )
					{
						// javascript calls actionscript
						case currLocation.indexOf( 'about:[SWVData]' ) != -1:
							e.preventDefault();
							_bridge.parseCallBack( currLocation.split( 'about:[SWVData]' )[1] );
							break;
						// load local pages
						case currLocation.indexOf( 'applink:' ) != -1:
							e.preventDefault();
							loadLocalURL( currLocation );
							break;
					}
					break;
				default:
					dispatchEvent( e );
					break;
			}
		}

		/**
		 * Overrides default addEventListener behavior to proxy LOCATION_CHANGING events through the original StageWebView
		 * This lets us to prevent the LOCATION_CHANGING event 
		 */
		override public function addEventListener( type : String, listener : Function, useCapture : Boolean = false, priority : int = 0, useWeakReference : Boolean = false ) : void
		{
			switch( type )
			{
				case LocationChangeEvent.LOCATION_CHANGING:
					_view.addEventListener( type, listener, useCapture, priority, useWeakReference );
					break;
				default:
					super.addEventListener( type, listener, useCapture, priority, useWeakReference );
					break;
			}
		}

		/**
		 * Overrides default removeEventListener behavior to proxy LOCATION_CHANGING events through the original StageWebView
		 * This lets us to prevent the LOCATION_CHANGING event 
		 */
		override public function removeEventListener( type : String, listener : Function, useCapture : Boolean = false ) : void
		{
			switch( type )
			{
				case LocationChangeEvent.LOCATION_CHANGING:
					_view.removeEventListener( type, listener, useCapture );
					break;
				default:
					super.removeEventListener( type, listener, useCapture );
					break;
			}
		}

		/* PROXING SOME PROPIERTIES */
		public function set viewPort( rectangle : Rectangle ) : void
		{
			_view.viewPort = rectangle;
		}

		public function get viewPort() : Rectangle
		{
			return _view.viewPort;
		}

		public function get isHistoryBackEnabled() : Boolean
		{
			return _view.isHistoryBackEnabled;
		}

		public function get isHistoryForwardEnabled() : Boolean
		{
			return _view.isHistoryForwardEnabled;
		}

		public function get location() : String
		{
			return _view.location;
		}

		public function get title() : String
		{
			return _view.title;
		}

		/* PROXING SOME METHODS */
		public function assignFocus( direction : String = "none" ) : void
		{
			_view.assignFocus( direction );
		}

		public function dispose() : void
		{
			_view.removeEventListener( Event.COMPLETE, onListener );
			_view.removeEventListener( ErrorEvent.ERROR, onListener );
			_view.removeEventListener( FocusEvent.FOCUS_IN, onListener );
			_view.removeEventListener( FocusEvent.FOCUS_OUT, onListener );
			_view.removeEventListener( LocationChangeEvent.LOCATION_CHANGE, onListener );
			_view.removeEventListener( LocationChangeEvent.LOCATION_CHANGING, onListener );
			_view.dispose();
			bitmapData.dispose();
			_view = null;
			_viewPort = null;
			_tmpFile = null;
			_bridge = null;
			System.gc();
		}

		public function historyBack() : void
		{
			_view.historyBack();
		}

		public function historyForward() : void
		{
			_view.historyForward();
		}

		/**
		 * Loads a local htmlFile into the webview.
		 * 
		 * To link files in html use the "applink:/" protocol:
		 * <a href="applink:/index.html">index</a>
		 * 
		 * For images,css,scripts... etc, use the "appfile:/" protocol:
		 * <img src="appfile:/image.png">
		 * 
		 * @param url	The url file with applink:/ protocol
		 * 				
		 * 				Usage: stageWebViewBridge.loadLocalURL('applink:/index.html');
		 */
		public function loadLocalURL( url : String ) : void
		{
			_tmpFile.nativePath = StageWebViewDisk.getFilePath( url.split( 'applink:/' )[1] );
			_view.loadURL( _tmpFile.url );
		}

		public function loadURL( url : String ) : void
		{
			_view.loadURL( url );
		}

		/**
		 * Enhaced loadString
		 * Loads a string and inject the javascript comunication code into it. 
		 */
		public function loadString( text : String, mimeType : String = "text/html" ) : void
		{
			text = text.replace( new RegExp( 'appfile:', 'g' ), StageWebViewDisk.applicationCacheDirectory );
			text = text.replace( new RegExp( '<head>', 'g' ), '<head><script type="text/javascript">' + StageWebViewDisk.JSCODE + '</script>' );
			_view.loadString( text, mimeType );
		}

		/**
		 * Creates and loads a temporally file with the provided contents.
		 * This way we can access local files with the appfile:/ protocol
		 * @params String content
		 */
		public function loadLocalString( content : String ) : void
		{
			_view.loadURL( new File( StageWebViewDisk.createTempFile( content ).nativePath ).url );
		}

		public function reload() : void
		{
			_view.reload();
		}

		public function stop() : void
		{
			_view.stop();
		}

		/**
		 * Sets the size of the StageWebView Instance
		 * @param w The width in pixels of StageWebView
		 * @param h The heigth in pixels of StageWebView
		 */
		public function setSize( w : uint, h : uint ) : void
		{
			_viewPort.width = w;
			_viewPort.height = h;
			viewPort = _viewPort;
			generateSnapShotBitmap();
		}

		override public function get x() : Number
		{
			return super.x;
		}

		override public function set x( ax : Number ) : void
		{
			super.x = ax;
			_viewPort.x = localToGlobal( _zeroPoint ).x;
			viewPort = _viewPort;
		}

		override public function get y() : Number
		{
			return super.y;
		}

		override public function set y( ay : Number ) : void
		{
			super.y = ay;
			_viewPort.y = localToGlobal( _zeroPoint ).y;
			viewPort = _viewPort;
		}

		override public function get visible() : Boolean
		{
			return super.visible;
		}

		override public function set visible( value : Boolean ) : void
		{
			if ( stage )
			{
				super.visible = value;
				_view.stage = value ? ( _snapShotVisible ? null : stage ) : null;
			}
		}

		/**
		 * draws a snapshot of StageWebView to the Bitmap
		 */
		public function getSnapShot() : void
		{
			_view.drawViewPortToBitmapData( bitmapData );
			var bridge : StageWebViewBridge = this;
			addEventListener( Event.ENTER_FRAME, function( e : Event ) : void
			{
				e.currentTarget.removeEventListener( e.type, arguments.callee );
				bridge.dispatchEvent( new StageWebViewBridgeEvent( StageWebViewBridgeEvent.ON_GET_SNAPSHOT ) );
			}, false, 0, true );
		}

		/**
		 * Enables / Disables the visibility of the SnapShotBitmap
		 * @param mode	Boolean.
		 */
		public function set snapShotVisible( mode : Boolean ) : void
		{
			_snapShotVisible = mode;
			_view.stage = mode ? null : ( visible ? null : stage );
			super.visible = mode;
		}

		/**
		 * Generates a new BitmapData for the new dimensions
		 */
		private function generateSnapShotBitmap() : void
		{
			bitmapData = new BitmapData( _viewPort.width, _viewPort.height, false, 0x000000 );
		}

		public function call( functionName : String, callback : Function = null, ... arguments ) : void
		{
			_bridge.call.apply( null, [ functionName, callback ].concat( arguments ) );
		}

		public function addCallback( name : String, callback : Function ) : void
		{
			_bridge.addCallback( name, callback );
		}
	}
}