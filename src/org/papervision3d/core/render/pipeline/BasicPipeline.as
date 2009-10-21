package org.papervision3d.core.render.pipeline
{
	import flash.geom.Matrix3D;
	import flash.geom.Rectangle;
	import flash.geom.Utils3D;
	import flash.geom.Vector3D;
	
	import org.papervision3d.cameras.Camera3D;
	import org.papervision3d.core.geom.provider.VertexGeometry;
	import org.papervision3d.core.ns.pv3d;
	import org.papervision3d.core.proto.Transform3D;
	import org.papervision3d.core.render.data.RenderData;
	import org.papervision3d.core.render.object.ObjectRenderer;
	import org.papervision3d.objects.DisplayObject3D;
	import org.papervision3d.objects.lights.ILight;
	
	public class BasicPipeline implements IRenderPipeline
	{
		use namespace pv3d;
		
		public var camera :Camera3D;
		public var projection :Matrix3D;
		
		private var _lookAts :Vector.<DisplayObject3D>;
		private var _defaultAt :Vector3D;
		private var _defaultUp :Vector3D;
		private var _pos :Vector3D;
		
		public function BasicPipeline()
		{
			_lookAts = new Vector.<DisplayObject3D>();
			
			_defaultAt = new Vector3D(0, 0, -1);
			_defaultUp = new Vector3D(0, -1, 0);
			_pos = new Vector3D();
		}
		
		public function execute(renderData:RenderData):void
		{
			var rect :Rectangle = renderData.viewport.sizeRectangle;
			
			camera = renderData.camera;	
			
			_lookAts.length = 0;

			transformToWorld(renderData.scene, renderData);

			if (_lookAts.length)
			{
				processLookAt();	
			}
			
			camera.update(rect);
			projection = camera.projectionMatrix;
			
			transformToView(camera, renderData.scene);
		}
		
		public function processLookAt():void
		{
			while (_lookAts.length)
			{
				var object :DisplayObject3D = _lookAts.pop();
				var targetTM :Transform3D = object.transform.scheduledLookAt;
				var sourceTM :Transform3D = object.transform;
				var wt :Matrix3D = object.transform.worldTransform;
				var target :Vector3D = targetTM.position;
				var eye :Vector3D = object.transform.position;

				_pos.x = target.x - eye.x;
				_pos.y = target.y - eye.y;
				_pos.z = target.z - eye.z;
				
				wt.identity();
				wt.pointAt(_pos, _defaultAt, _defaultUp);
				wt.appendTranslation(eye.x, eye.y, eye.z);
			}
		}
		
		public function transformToWorld(object:DisplayObject3D, renderData:RenderData):void
		{
			var transform :Transform3D = object.transform;
			var child :DisplayObject3D;
			var wt :Matrix3D = object.transform.worldTransform;
			
			if (object.transform.scheduledLookAt)
			{
				_lookAts.push(object);
			}

			wt.rawData = object.transform.localToWorldMatrix.rawData;

			if (object.parent)
			{
				wt.append(object.parent.transform.worldTransform);
			}
			
			transform.rotateGlob(1, 0, 0, transform.eulerAngles.x, wt);
			transform.rotateGlob(0, 1, 0, transform.eulerAngles.y, wt);
			transform.rotateGlob(0, 0, 1, transform.eulerAngles.z, wt);
			
			wt.prependScale(transform.localScale.x, transform.localScale.y, transform.localScale.z);
			
			object.transform.position = wt.position;
			
			if(object is ILight){
				renderData.lights.addLight(object as ILight);
			}

			for each(child in object._children)
			{
				transformToWorld(child, renderData);
			}
		}
		
		/**
		 * 
		 */ 
		protected function transformToView(camera:Camera3D, object:DisplayObject3D):void
		{
			var child :DisplayObject3D;
			var wt :Matrix3D = object.transform.worldTransform;
			var vt :Matrix3D = object.transform.viewTransform;
			
			vt.rawData = wt.rawData;
			vt.append(camera.viewMatrix);
			
			if (object.renderer.geometry is VertexGeometry)
			{
				projectVertices(camera, object);
			}
			
			for each (child in object._children)
			{
				transformToView(camera, child);
			}
		}
		
		/**
		 * 
		 */ 
		protected function projectVertices(camera:Camera3D, object:DisplayObject3D):void
		{
			var vt :Matrix3D = object.transform.viewTransform;
			var st :Matrix3D = object.transform.screenTransform;
			var renderer : ObjectRenderer = object.renderer;
			// move the vertices into view / camera space
			// we'll need the vertices in this space to check whether vertices are behind the camera.
			// if we move to screen space in one go, screen vertices could move to infinity.
			vt.transformVectors(renderer.geometry.vertexData, renderer.viewVertexData);
			
			// append the projection matrix to the object's view matrix
			st.rawData = vt.rawData;
			st.append(camera.projectionMatrix);
			
			// move the vertices to screen space.
			// AKA: the perspective divide
			// NOTE: some vertices may have moved to infinity, we need to check while processing triangles.
			//       IF so we need to check whether we need to clip the triangles or disgard them.
			Utils3D.projectVectors(st, renderer.geometry.vertexData, renderer.screenVertexData, renderer.uvtData);
		}
	}
}