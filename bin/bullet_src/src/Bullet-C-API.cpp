/*
Bullet Continuous Collision Detection and Physics Library
Copyright (c) 2003-2006 Erwin Coumans  http://continuousphysics.com/Bullet/

This software is provided 'as-is', without any express or implied warranty.
In no event will the authors be held liable for any damages arising from the use of this software.
Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it freely,
subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.
*/

/*
	Draft high-level generic physics C-API. For low-level access, use the physics SDK native API's.
	Work in progress, functionality will be added on demand.

	If possible, use the richer Bullet C++ API, by including <src/btBulletDynamicsCommon.h>
*/

#include <stdio.h> //printf debugging

#include "Bullet-C-Api.h"

#include "btBulletDynamicsCommon.h"
#include "LinearMath/btAlignedAllocator.h"


#include "LinearMath/btVector3.h"
#include "LinearMath/btScalar.h"
#include "LinearMath/btMatrix3x3.h"
#include "LinearMath/btTransform.h"
#include "BulletCollision/NarrowPhaseCollision/btVoronoiSimplexSolver.h"
#include "BulletCollision/CollisionShapes/btTriangleShape.h"
#include "BulletCollision/CollisionShapes/btHeightfieldTerrainShape.h"

#include "BulletCollision/NarrowPhaseCollision/btGjkPairDetector.h"
#include "BulletCollision/NarrowPhaseCollision/btPointCollector.h"
#include "BulletCollision/NarrowPhaseCollision/btVoronoiSimplexSolver.h"
#include "BulletCollision/NarrowPhaseCollision/btSubSimplexConvexCast.h"
#include "BulletCollision/NarrowPhaseCollision/btGjkEpaPenetrationDepthSolver.h"
#include "BulletCollision/NarrowPhaseCollision/btGjkEpa2.h"
#include "BulletCollision/CollisionShapes/btMinkowskiSumShape.h"
#include "BulletCollision/NarrowPhaseCollision/btDiscreteCollisionDetectorInterface.h"
#include "BulletCollision/NarrowPhaseCollision/btSimplexSolverInterface.h"
#include "BulletCollision/NarrowPhaseCollision/btMinkowskiPenetrationDepthSolver.h"
#include "LinearMath/btStackAlloc.h"

#define assert()
#define tobtvec3(v) btVector3(v[0], v[1], v[2])
#define tobtquat(v) btQuaternion(v[0], v[1], v[2], v[3])
/*
	Create3 and Delete a Physics SDK
*/

struct	btPhysicsSdk
{

	//	btDispatcher*				m_dispatcher;
	//	btOverlappingPairCache*		m_pairCache;
	//	btConstraintSolver*			m_constraintSolver

	btVector3	m_worldAabbMin;
	btVector3	m_worldAabbMax;


	//todo: version, hardware/optimization settings etc?
	btPhysicsSdk()
		: m_worldAabbMin(-1000, -1000, -1000),
		  m_worldAabbMax(1000, 1000, 1000)
	{
	}
};

plPhysicsSdkHandle	plNewBulletSdk()
{
	void *mem = btAlignedAlloc(sizeof(btPhysicsSdk), 16);
	return (plPhysicsSdkHandle)new (mem)btPhysicsSdk;
}

void		plDeletePhysicsSdk(plPhysicsSdkHandle	physicsSdk)
{
	btPhysicsSdk *phys = reinterpret_cast<btPhysicsSdk *>(physicsSdk);
	btAlignedFree(phys);
}



/* Dynamics World */
plDynamicsWorldHandle plCreateDynamicsWorld(plVector3 worldMin, plVector3 worldMax)
{
	//btPhysicsSdk* physicsSdk = reinterpret_cast<btPhysicsSdk*>(physicsSdkHandle);
	void *mem = btAlignedAlloc(sizeof(btDefaultCollisionConfiguration), 16);
	btDefaultCollisionConfiguration *collisionConfiguration = new (mem) btDefaultCollisionConfiguration();
	mem = btAlignedAlloc(sizeof(btCollisionDispatcher), 16);
	btDispatcher				*dispatcher = new (mem)btCollisionDispatcher(collisionConfiguration);
	mem = btAlignedAlloc(sizeof(btAxisSweep3), 16);
	btBroadphaseInterface		*pairCache = new (mem)btAxisSweep3(tobtvec3(worldMin), tobtvec3(worldMax));
	mem = btAlignedAlloc(sizeof(btSequentialImpulseConstraintSolver), 16);
	btConstraintSolver			*constraintSolver = new(mem) btSequentialImpulseConstraintSolver();
	mem = btAlignedAlloc(sizeof(btDiscreteDynamicsWorld), 16);
	return (plDynamicsWorldHandle) new (mem)btDiscreteDynamicsWorld(dispatcher, pairCache, constraintSolver, collisionConfiguration);
}

void plDeleteDynamicsWorld(plDynamicsWorldHandle world)
{
	//todo: also clean up the other allocations, axisSweep, pairCache,dispatcher,constraintSolver,collisionConfiguration
	btDynamicsWorld *dynamicsWorld = reinterpret_cast< btDynamicsWorld * >(world);
	dynamicsWorld->~btDynamicsWorld();
	btAlignedFree(dynamicsWorld);
}

void plStepSimulation(plDynamicsWorldHandle world,	plReal	timeStep)
{
	btDynamicsWorld *dynamicsWorld = reinterpret_cast< btDynamicsWorld * >(world);
	assert(dynamicsWorld);
	dynamicsWorld->stepSimulation(timeStep);
}

void plAddRigidBody(plDynamicsWorldHandle world, plRigidBodyHandle object)
{
	btDynamicsWorld *dynamicsWorld = reinterpret_cast< btDynamicsWorld * >(world);
	assert(dynamicsWorld);
	btRigidBody *body = reinterpret_cast< btRigidBody * >(object);
	assert(body);
	dynamicsWorld->addRigidBody(body);
}

void pl_DynamicsWorld_addVehicle(plDynamicsWorldHandle world, plConstraintHandle vehicle)
{
	return reinterpret_cast< btDynamicsWorld * >(world)->addVehicle(reinterpret_cast< btRaycastVehicle * >(vehicle));
}

void pl_DynamicsWorld_removeVehicle(plDynamicsWorldHandle world, plConstraintHandle vehicle)
{
	return reinterpret_cast< btDynamicsWorld * >(world)->removeVehicle(reinterpret_cast< btRaycastVehicle * >(vehicle));
}

extern ContactProcessedCallback gContactProcessedCallback;
void pl_setCollisionProcessedCallback( ContactProcessedCallback fn )
{
	gContactProcessedCallback = fn;
}

void plRemoveRigidBody(plDynamicsWorldHandle world, plRigidBodyHandle object)
{
	btDynamicsWorld *dynamicsWorld = reinterpret_cast< btDynamicsWorld * >(world);
	assert(dynamicsWorld);
	btRigidBody *body = reinterpret_cast< btRigidBody * >(object);
	assert(body);
	dynamicsWorld->removeRigidBody(body);
}

int pl_DynamicsWorld_getNumCollisionObjects(plDynamicsWorldHandle world)
{
	btDynamicsWorld *dynamicsWorld = reinterpret_cast< btDynamicsWorld * >(world);
	assert(dynamicsWorld);
	return dynamicsWorld->getNumCollisionObjects();
}

// fixme: only handles rigid bodies (returns NULL for soft bodies etc)
plRigidBodyHandle pl_DynamicsWorld_getCollisionObject(plDynamicsWorldHandle world, int objectIndex)
{
	btDynamicsWorld *dynamicsWorld = reinterpret_cast< btDynamicsWorld * >(world);
	assert(dynamicsWorld);
	return (plRigidBodyHandle)btRigidBody::upcast(dynamicsWorld->getCollisionObjectArray()[objectIndex]);
}

/* Rigid Body  */
plRigidBodyHandle plCreateRigidBody(void *user_data, float mass, plCollisionShapeHandle cshape )
{
	btTransform trans;
	trans.setIdentity();
	btVector3 localInertia(0, 0, 0);
	btCollisionShape *shape = reinterpret_cast<btCollisionShape *>( cshape);
	assert(shape);

	if (mass)
	{
		shape->calculateLocalInertia(mass, localInertia);
	}

	void *mem = btAlignedAlloc(sizeof(btRigidBody), 16);
	/**
	 * Eike:
	 * - if the motionState is created here, the car will sometimes be reset
	 *   to (0,0,0) because the motionState has no usefull position stored.
	 *
	 * - bullet docs suggest to create a motionstate that remembers the last
	 *   position we have set for it.
	 *   (http://www.bulletphysics.com/mediawiki-1.5.8/index.php?title=MotionStates)
	 *
	 * - it seems to work for now though.
	 */
	//btDefaultMotionState* myMotionState = new btDefaultMotionState(trans);
	btDefaultMotionState *myMotionState = NULL;
	btRigidBody::btRigidBodyConstructionInfo cInfo(mass, myMotionState, shape, localInertia);
	btRigidBody *body = new btRigidBody(cInfo);
	/*	btRigidBody::btRigidBodyConstructionInfo rbci(mass, 0,shape,localInertia);
		btRigidBody* body = new (mem)btRigidBody(rbci);*/
	body->setWorldTransform(trans);
	body->setUserPointer(user_data);
	return (plRigidBodyHandle) body;
}

void plSetActivationState(plRigidBodyHandle cbody, int state)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(cbody);
	body->setActivationState(state);
}

void plDeleteRigidBody(plRigidBodyHandle cbody)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(cbody);
	assert(body);
	btAlignedFree( body);
}

void pl_RigidBody_setActivationState(plRigidBodyHandle cbody, int newState)
{
	reinterpret_cast< btRigidBody * >(cbody)->setActivationState(newState);
}

void pl_RigidBody_setCollisionFlags(plRigidBodyHandle cbody, int flags)
{
	reinterpret_cast< btRigidBody * >(cbody)->setCollisionFlags(flags);
}


int pl_RigidBody_getCollisionFlags(plRigidBodyHandle cbody)
{
	return reinterpret_cast< btRigidBody * >(cbody)->getCollisionFlags();
}

void pl_RigidBody_getOpenGLMatrix(plRigidBodyHandle cbody, plReal *mtx)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(cbody);
	assert(body);

	if (body->getMotionState())
	{
		btDefaultMotionState *myMotionState = (btDefaultMotionState *)body->getMotionState();
		myMotionState->m_graphicsWorldTrans.getOpenGLMatrix(mtx);
	}
	else
	{
		body->getWorldTransform().getOpenGLMatrix(mtx);
	}
}

plCollisionShapeHandle pl_RigidBody_getCollisionShape(plRigidBodyHandle cbody)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(cbody);
	assert(body);
	return (plCollisionShapeHandle)body->getCollisionShape();
}

/* Collision Shape definition */

plCollisionShapeHandle plNewSphereShape(plReal radius)
{
	void *mem = btAlignedAlloc(sizeof(btSphereShape), 16);
	return (plCollisionShapeHandle) new (mem)btSphereShape(radius);
}

plCollisionShapeHandle plNewBoxShape(plReal x, plReal y, plReal z)
{
	void *mem = btAlignedAlloc(sizeof(btBoxShape), 16);
	return (plCollisionShapeHandle) new (mem)btBoxShape(btVector3(x, y, z));
}

/*plCollisionShapeHandle plNewCapsuleShape(plReal radius, plReal height)
{
	//capsule is convex hull of 2 spheres, so use btMultiSphereShape
	btVector3 inertiaHalfExtents(radius,height,radius);
	const int numSpheres = 2;
	btVector3 positions[numSpheres] = {btVector3(0,height,0),btVector3(0,-height,0)};
	btScalar radi[numSpheres] = {radius,radius};
	void* mem = btAlignedAlloc(sizeof(btMultiSphereShape),16);
	return (plCollisionShapeHandle) new (mem)btMultiSphereShape(inertiaHalfExtents,positions,radi,numSpheres);
}*/
plCollisionShapeHandle plNewConeShape(plReal radius, plReal height)
{
	void *mem = btAlignedAlloc(sizeof(btConeShape), 16);
	return (plCollisionShapeHandle) new (mem)btConeShape(radius, height);
}

plCollisionShapeHandle plNewCylinderShape(plReal radius, plReal height)
{
	void *mem = btAlignedAlloc(sizeof(btCylinderShape), 16);
	return (plCollisionShapeHandle) new (mem)btCylinderShape(btVector3(radius, height, radius));
}

/* Convex Meshes */
plCollisionShapeHandle plNewConvexHullShape()
{
	void *mem = btAlignedAlloc(sizeof(btConvexHullShape), 16);
	return (plCollisionShapeHandle) new (mem)btConvexHullShape();
}


/* Concave static triangle meshes */
plMeshInterfaceHandle plNewMeshInterface()
{
	return 0;
}

plHeightFieldHandle plNewHeightField(double *&heightfieldData, FILE *heightFieldFile, FILEFORMAT_HEIGHTFIELD_HEADER *hdr)
{
	int i;
	const float TRIANGLE_SIZE = 5.f;
	//create a triangle-mesh ground
	int vertStride = sizeof(btVector3);
	int indexStride = 3 * sizeof(int);
	int upIndex = 1;
	btTriangleIndexVertexArray *m_indexVertexArrays;
	btCollisionShape *groundShape = NULL;

	if (heightFieldFile)
	{
		int numXVertices = hdr->NumXVertices;
		int numZVertices = hdr->NumZVertices;
		heightfieldData = new double[numXVertices * numZVertices];
		{
			for (int i = 0; i < numXVertices * numZVertices; i++)
			{
				heightfieldData[i] = 0;
			}
		}
		size_t numBytes = fread(heightfieldData, sizeof(double), numXVertices * numZVertices, heightFieldFile);

		if(!numBytes)
		{
			printf("couldn't read heightfield at %s\n", heightFieldFile);
		}

		fclose(heightFieldFile);
		btScalar maxHeight = 20000.f;
		bool     useFloatDatam = true;
		bool     flipQuadEdges = false;
		btHeightfieldTerrainShape *heightFieldShape = new btHeightfieldTerrainShape(numXVertices, numZVertices, heightfieldData, maxHeight, upIndex, useFloatDatam, flipQuadEdges);;
		groundShape = heightFieldShape;
		heightFieldShape->setUseDiamondSubdivision(true);
		btVector3 localScaling(hdr->Width / float(numXVertices - 1), 1, hdr->Length / float(numZVertices - 1));
		groundShape->setLocalScaling(localScaling);
	}
	else
	{
		const int NUM_VERTS_X = 20;
		const int NUM_VERTS_Y = 20;
		const int totalVerts = NUM_VERTS_X * NUM_VERTS_Y;
		const int totalTriangles = 2 * (NUM_VERTS_X - 1) * (NUM_VERTS_Y - 1);
		btVector3 *m_vertices = new btVector3[totalVerts];
		int	*gIndices = new int[totalTriangles * 3];

		for ( i = 0; i < NUM_VERTS_X; i++)
		{
			for (int j = 0; j < NUM_VERTS_Y; j++)
			{
				float wl = .2f;
				//height set to zero, but can also use curved landscape, just uncomment out the code
				float height = 20.f * sinf(float(i * 2) * wl) * cosf(float(j * 2) * wl);
				m_vertices[i + j * NUM_VERTS_X].setValue(
					(i - NUM_VERTS_X * 0.5f)*TRIANGLE_SIZE,
					height,
					(j - NUM_VERTS_Y * 0.5f)*TRIANGLE_SIZE);
			}
		}

		int index = 0;

		for ( i = 0; i < NUM_VERTS_X - 1; i++)
		{
			for (int j = 0; j < NUM_VERTS_Y - 1; j++)
			{
				gIndices[index++] = j * NUM_VERTS_X + i;
				gIndices[index++] = j * NUM_VERTS_X + i + 1;
				gIndices[index++] = (j + 1) * NUM_VERTS_X + i + 1;
				gIndices[index++] = j * NUM_VERTS_X + i;
				gIndices[index++] = (j + 1) * NUM_VERTS_X + i + 1;
				gIndices[index++] = (j + 1) * NUM_VERTS_X + i;
			}
		}

		m_indexVertexArrays = new btTriangleIndexVertexArray(totalTriangles,
				gIndices,
				indexStride,
				totalVerts, (btScalar *) &m_vertices[0].x(), vertStride);
		bool useQuantizedAabbCompression = true;
		groundShape = new btBvhTriangleMeshShape(m_indexVertexArrays, useQuantizedAabbCompression);
	}

	return (plHeightFieldHandle) groundShape;
}

plCollisionShapeHandle plNewCompoundShape()
{
	void *mem = btAlignedAlloc(sizeof(btCompoundShape), 16);
	return (plCollisionShapeHandle) new (mem)btCompoundShape();
}

plCollisionShapeHandle plCreateBvhTriangleMeshShape(int numTriangles, int *triangleIndexBase, int triangleIndexStride, int numVertices, plReal *vertexBase, int vertexStride, int bUseQuantizedAabbCompression)
{
	btTriangleIndexVertexArray *indexVertexArrays = new btTriangleIndexVertexArray(
		numTriangles, triangleIndexBase, triangleIndexStride, numVertices,
		vertexBase, vertexStride);
	void *mem = btAlignedAlloc(sizeof(btBvhTriangleMeshShape), 16);
	return (plCollisionShapeHandle) new (mem)btBvhTriangleMeshShape(indexVertexArrays, bUseQuantizedAabbCompression ? true : false);
}

plCollisionShapeHandle plCreateDeserializedBvhTriangleMeshShape(
	int numTriangles, int *triangleIndexBase, int triangleIndexStride, int numVertices, plReal *vertexBase, int vertexStride, int bUseQuantizedAabbCompression,
	unsigned char *buffer, size_t bufferSize, int bSwapEndian)
{
	btTriangleIndexVertexArray *indexVertexArrays = new btTriangleIndexVertexArray(
		numTriangles, triangleIndexBase, triangleIndexStride, numVertices,
		vertexBase, vertexStride);
	void *mem = btAlignedAlloc(sizeof(btBvhTriangleMeshShape), 16);
	btBvhTriangleMeshShape *triMeshShape = (btBvhTriangleMeshShape *) new (mem)btBvhTriangleMeshShape(indexVertexArrays, bUseQuantizedAabbCompression ? true : false, false);
	btOptimizedBvh *bvh = btOptimizedBvh::deSerializeInPlace(buffer, (unsigned)bufferSize, bSwapEndian ? true : false);
	triMeshShape->setOptimizedBvh(bvh);
	return (plCollisionShapeHandle) triMeshShape;
}


void pl_BvhTriangleMeshShape_Serialize(plCollisionShapeHandle triShape, unsigned char **memBuf, size_t *memBufSize, int bSwapEndianness)
{
	btBvhTriangleMeshShape *trimeshShape  = reinterpret_cast<btBvhTriangleMeshShape *>(triShape);
	*memBufSize = trimeshShape->getOptimizedBvh()->calculateSerializeBufferSize();
	size_t paddedSize = btOptimizedBvh::getAlignmentSerializationPadding() + *memBufSize;
	*memBuf = (unsigned char *)btAlignedAlloc(paddedSize, 16);
	trimeshShape->getOptimizedBvh()->serialize(*memBuf, (unsigned)*memBufSize, bSwapEndianness ? true : false);
}

void pl_BvhTriangleMeshShape_SerializeDone(plCollisionShapeHandle triShape, unsigned char *memBuf)
{
	btAlignedFree(memBuf);
}



void plAddChildShape(plCollisionShapeHandle compoundShapeHandle, plCollisionShapeHandle childShapeHandle, plVector3 childPos, plQuaternion childOrn)
{
	btCollisionShape *colShape = reinterpret_cast<btCollisionShape *>(compoundShapeHandle);
	btAssert(colShape->getShapeType() == COMPOUND_SHAPE_PROXYTYPE);
	btCompoundShape *compoundShape = reinterpret_cast<btCompoundShape *>(colShape);
	btCollisionShape *childShape = reinterpret_cast<btCollisionShape *>(childShapeHandle);
	btTransform	localTrans;
	localTrans.setIdentity();
	localTrans.setOrigin(btVector3(childPos[0], childPos[1], childPos[2]));
	localTrans.setRotation(btQuaternion(childOrn[0], childOrn[1], childOrn[2], childOrn[3]));
	compoundShape->addChildShape(localTrans, childShape);
}

void pl_CompoundShape_addChildShape(plCollisionShapeHandle compoundShapeHandle, plCollisionShapeHandle childShapeHandle,  const plTransform *transform)
{
	btCompoundShape *colShape = reinterpret_cast<btCompoundShape *>(compoundShapeHandle);
	btAssert(colShape->getShapeType() == COMPOUND_SHAPE_PROXYTYPE);
	btCollisionShape *childShape = reinterpret_cast<btCollisionShape *>(childShapeHandle);
	colShape->addChildShape(*((btTransform *)transform), childShape);
}




int pl_CollisionShape_getShapeType(plCollisionShapeHandle shape)
{
	btCollisionShape *colShape = reinterpret_cast<btCollisionShape *>(shape);
	btAssert(colShape);
	return colShape->getShapeType();
}

int pl_CollisionShape_isConcave(plCollisionShapeHandle shape)
{
	return reinterpret_cast<btCollisionShape *>(shape)->isConcave();
}

void *pl_CollisionShape_getUserPointer(plCollisionShapeHandle shape)
{
	return reinterpret_cast<btCollisionShape *>(shape)->getUserPointer();
}

void pl_CollisionShape_setUserPointer(plCollisionShapeHandle shape, void *up)
{
	reinterpret_cast<btCollisionShape *>(shape)->setUserPointer(up);
}

plReal pl_UniformScalingShape_getUniformScalingFactor(plCollisionShapeHandle shape)
{
	btUniformScalingShape *colShape = reinterpret_cast<btUniformScalingShape *>(shape);
	btAssert(colShape);
	return colShape->getUniformScalingFactor();
}

plCollisionShapeHandle pl_UniformScalingShape_getChildShape(plCollisionShapeHandle shape)
{
	return (plCollisionShapeHandle) reinterpret_cast<btUniformScalingShape *>(shape)->getChildShape();
}


int pl_CompoundShape_getNumChildShapes(plCollisionShapeHandle shape)
{
	btCompoundShape *colShape = reinterpret_cast<btCompoundShape *>(shape);
	btAssert(colShape);
	return colShape->getNumChildShapes();
}

plCollisionShapeHandle pl_CompoundShape_getChildShape(plCollisionShapeHandle shape, int childIndex)
{
	btCompoundShape *colShape = reinterpret_cast<btCompoundShape *>(shape);
	btAssert(colShape);
	return (plCollisionShapeHandle)colShape->getChildShape(childIndex);
}

void pl_CompoundShape_getChildTransform(plCollisionShapeHandle shape, int childIndex, plTransform *childTransform)
{
	btTransform tr = reinterpret_cast<btCompoundShape *>(shape)->getChildTransform(childIndex);
	memcpy(childTransform, &tr, sizeof(btTransform));
}

void pl_BoxShape_getHalfExtentsWithMargin(plCollisionShapeHandle shape, plReal *halfExtents)
{
	btBoxShape *colShape = reinterpret_cast<btBoxShape *>(shape);
	btAssert(colShape);
	btVector3 v = colShape->getHalfExtentsWithMargin();
	halfExtents[0] = v.getX();
	halfExtents[1] = v.getY();
	halfExtents[2] = v.getZ();
}


static btVector3 aabbMaxDefault(btScalar(1e30), btScalar(1e30), btScalar(1e30));
static btVector3 aabbMinDefault(-btScalar(1e30), -btScalar(1e30), -btScalar(1e30));



void pl_ConcaveShape_processAllTriangles(plCollisionShapeHandle shape, plprocessTriangle_t callback, void *callbackOpaque, plVector3 aabbMin, plVector3 aabbMax)
{
	btConcaveShape *colShape = reinterpret_cast<btConcaveShape *>(shape);
	btAssert(colShape);
	class TriangleCB : public btTriangleCallback
	{
		public:
			TriangleCB(plprocessTriangle_t f, void *ud) : m_CallbackFunction(f), m_OpaquePointer(ud) {}
			virtual void processTriangle(btVector3 *triangle, int partId, int triangleIndex)
			{
				m_CallbackFunction(m_OpaquePointer, (plReal *)triangle, partId, triangleIndex);
			}

			plprocessTriangle_t m_CallbackFunction;
			void *m_OpaquePointer;
	};
	TriangleCB cb(callback, callbackOpaque);
	colShape->processAllTriangles(&cb, tobtvec3(aabbMin), tobtvec3(aabbMax));
}

/* Constraints */
plConstraintHandle plCreateVehicle(plDynamicsWorldHandle world, const btRaycastVehicle::btVehicleTuning *tuning, plRigidBodyHandle chassis)
{
	btDynamicsWorld *dynamicsWorld = reinterpret_cast< btDynamicsWorld * >(world);
	void *mem = btAlignedAlloc(sizeof(btRaycastVehicle), 16);
	btDefaultVehicleRaycaster *rc = (btDefaultVehicleRaycaster *)btAlignedAlloc(sizeof(btDefaultVehicleRaycaster), 16);
	new(rc) btDefaultVehicleRaycaster(dynamicsWorld);   // fixme: leak
	return (plConstraintHandle) new (mem) btRaycastVehicle(*tuning, reinterpret_cast<btRigidBody *>(chassis), rc);
}

/*void plDeleteVehicle(plConstraintHandle vehicle_)
{
	btRaycastVehicle* vehicle = reinterpret_cast< btRaycastVehicle* >(vehicle_);
	((btDefaultVehicleRaycaster*)vehicle->getRayCaster())->~btDefaultVehicleRaycaster();
	btAlignedFree(vehicle->getRayCaster());
	vehicle->~btRaycastVehicle();
	btAlignedFree(vehicle);
}

void pl_Vehicle_applyEngineTorque(plConstraintHandle vehicle, btScalar force)
{
	reinterpret_cast< btRaycastVehicle* >(vehicle)->applyEngineTorque(force);
}*/

void pl_Vehicle_setBrake(plConstraintHandle vehicle, plReal brakePower, plReal parkingBrakePower)
{
	reinterpret_cast< btRaycastVehicle * >(vehicle)->setBrake(brakePower, parkingBrakePower);
}

void pl_Vehicle_setSteeringValue(plConstraintHandle vehicle, plReal steeringValue, int wheelIndex)
{
	reinterpret_cast< btRaycastVehicle * >(vehicle)->setSteeringValue(steeringValue, wheelIndex);
}

plReal pl_Vehicle_getCurrentSpeed(plConstraintHandle vehicle)
{
	return reinterpret_cast< btRaycastVehicle * >(vehicle)->getCurrentSpeedKmHour() * ((plReal)(1.0 / 3.6));
}

plRigidBodyHandle pl_Vehicle_getRigidBody(plConstraintHandle vehicle)
{
	return (plRigidBodyHandle)(reinterpret_cast< btRaycastVehicle * >(vehicle)->getRigidBody());
}
/*
void pl_Vehicle_addWheel(plConstraintHandle vehicle, const plReal* connectionPointCS0, const plReal* wheelDirectionCS0, const plReal* wheelAxleCS, plReal suspensionRestLength, plReal wheelRadius, const btRaycastVehicle::btVehicleTuning* tuning, int isFrontWheel)
{
	reinterpret_cast< btRaycastVehicle* >(vehicle)->addWheel(
		connectionPointCS0, wheelDirectionCS0,
		wheelAxleCS, suspensionRestLength, wheelRadius, *tuning, isFrontWheel ? true : false);
}
*/
void pl_Vehicle_setCoordinateSystem(plConstraintHandle vehicle, int rightIndex, int upIndex, int forwardIndex)
{
	reinterpret_cast< btRaycastVehicle * >(vehicle)->setCoordinateSystem(rightIndex, upIndex, forwardIndex);
}


int pl_Vehicle_getNumWheels(plConstraintHandle vehicle)
{
	return reinterpret_cast< btRaycastVehicle * >(vehicle)->getNumWheels();
}

void pl_Vehicle_resetSuspension(plConstraintHandle vehicle)
{
	reinterpret_cast< btRaycastVehicle * >(vehicle)->resetSuspension();
}
/*
plReal pl_Vehicle_getRearAxleSpeed(plConstraintHandle vehicle)
{
	return reinterpret_cast< btRaycastVehicle* >(vehicle)->getRearAxleSpeed();
}

void pl_Vehicle_setAirDragMultiplier(plConstraintHandle vehicle, plReal airDragMultiplier)
{
	reinterpret_cast< btRaycastVehicle* >(vehicle)->setAirDragMultiplier(airDragMultiplier);
}

void pl_Vehicle_setRollingResistancePerWheel(plConstraintHandle vehicle, plReal rollingResistancePerWheel)
{
	reinterpret_cast< btRaycastVehicle* >(vehicle)->setRollingResistancePerWheel(rollingResistancePerWheel);
}

void pl_Vehicle_setSwayBarRate(plConstraintHandle vehicle, plReal swayBarRate)
{
	reinterpret_cast< btRaycastVehicle* >(vehicle)->setSwayBarRate(swayBarRate);
}

void pl_Vehicle_setRoadSurfaceProperties(plConstraintHandle vehicle, int materialIndex, const btRoadSurfaceProperties* roadSurfaceProps)
{
	reinterpret_cast< btRaycastVehicle* >(vehicle)->setRoadSurfaceProperties(materialIndex, *roadSurfaceProps);
}
*/
void pl_Vehicle_updateWheelTransform(plConstraintHandle vehicle, int wheelIndex, int bInterpolatedTransform)
{
	reinterpret_cast< btRaycastVehicle * >(vehicle)->updateWheelTransform(wheelIndex, bInterpolatedTransform ? true : false);
}

void pl_Vehicle_getWheelTransform(plConstraintHandle vehicle, int wheelIndex, plTransform *wheelTransform)
{
	memcpy(
		wheelTransform,
		&(reinterpret_cast< btRaycastVehicle * >(vehicle)->getWheelInfo(wheelIndex).m_worldTransform),
		sizeof(plTransform));
}

const btWheelInfo *pl_Vehicle_getWheelInfo(plConstraintHandle vehicle, int wheelIndex)
{
	return &(reinterpret_cast< btRaycastVehicle * >(vehicle)->getWheelInfo(wheelIndex));
}




void plSetEuler(plReal yaw, plReal pitch, plReal roll, plQuaternion orient)
{
	btQuaternion orn;
	orn.setEuler(yaw, pitch, roll);
	orient[0] = orn.getX();
	orient[1] = orn.getY();
	orient[2] = orn.getZ();
	orient[3] = orn.getW();
}

PLPROTO void plInitVector(plVector3 vec, plReal x, plReal y, plReal z)
{
	vec[0] = x;
	vec[1] = y;
	vec[2] = z;
}

PLPROTO void plSetQuadIdentity(plQuaternion a)
{
	a[0] = 0;
	a[1] = 0;
	a[2] = 0;
	a[3] = 1;
}

PLPROTO void plMultiplyQuat(const plQuaternion a, const plQuaternion b, plQuaternion out)
{
	plReal a0(a[0]), a1(a[1]), a2(a[2]), a3(a[3]),
		   b0(b[0]), b1(b[1]), b2(b[2]), b3(b[3]);
	out[0] = a3 * b0 + a0 * b3 + a1 * b2 - a2 * b1;
	out[1] = a3 * b1 + a1 * b3 + a2 * b0 - a0 * b2;
	out[2] = a3 * b2 + a2 * b3 + a0 * b1 - a1 * b0;
	out[3] = a3 * b3 - a0 * b0 - a1 * b1 - a2 * b2;
}

PLPROTO void plTransformVector(const plQuaternion quat, const plReal x, const plReal y, const plReal z, plVector3 out)
{
	// calculate q * v * q^-1
	plReal a(x * quat[3] - y * quat[2] + z * quat[1]);
	plReal b(y * quat[3] - z * quat[0] + x * quat[2]);
	plReal c(z * quat[3] - x * quat[1] + y * quat[0]);
	plReal d(x * quat[0] + y * quat[1] + z * quat[2]);
	out[0] = quat[3] * a + quat[0] * d + quat[1] * c - quat[2] * b;
	out[1] = quat[3] * b + quat[1] * d + quat[2] * a - quat[0] * c;
	out[2] = quat[3] * c + quat[2] * d + quat[0] * b - quat[1] * a;
}

PLPROTO void plAddVectors(const plVector3 &a, const plVector3 &b, plVector3 &res)
{
	res[0] = a[0] + b[0];
	res[1] = a[1] + b[1];
	res[2] = a[2] + b[2];
}

//	 void		plAddTriangle(plMeshInterfaceHandle meshHandle, plVector3 v0,plVector3 v1,plVector3 v2);
//	 plCollisionShapeHandle plNewStaticTriangleMeshShape(plMeshInterfaceHandle);


void		plAddVertex(plCollisionShapeHandle cshape, plReal x, plReal y, plReal z)
{
	btCollisionShape *colShape = reinterpret_cast<btCollisionShape *>( cshape);
	(void)colShape;
	btAssert(colShape->getShapeType() == CONVEX_HULL_SHAPE_PROXYTYPE);
	btConvexHullShape *convexHullShape = reinterpret_cast<btConvexHullShape *>( cshape);
	convexHullShape->addPoint(btVector3(x, y, z));
}

void plDeleteShape(plCollisionShapeHandle cshape)
{
	btCollisionShape *shape = reinterpret_cast<btCollisionShape *>( cshape);
	assert(shape);
	btAlignedFree(shape);
}

void plSetScaling(plCollisionShapeHandle cshape, plVector3 cscaling)
{
	btCollisionShape *shape = reinterpret_cast<btCollisionShape *>( cshape);
	assert(shape);
	btVector3 scaling(cscaling[0], cscaling[1], cscaling[2]);
	shape->setLocalScaling(scaling);
}


void plSetPosition(plRigidBodyHandle object, const plVector3 position)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(object);
	btAssert(body);
	btVector3 pos(position[0], position[1], position[2]);
	btTransform worldTrans = body->getWorldTransform();
	worldTrans.setOrigin(pos);
	body->setWorldTransform(worldTrans);
}

void plApplyImpulse(plRigidBodyHandle object, const plVector3 force)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(object);
	btVector3 f(force[0], force[1], force[2]);
	body->applyCentralImpulse(f);
}

void plApplyTorque(plRigidBodyHandle object, const plVector3 impulse)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(object);
	btVector3 f(impulse[0], impulse[1], impulse[2]);
	body->applyTorqueImpulse(f);
}

void plApplyDamping(plRigidBodyHandle object, plReal timeStep)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(object);
	body->applyDamping(timeStep);
}

void plGetLinearVelocity(plRigidBodyHandle object, plVector3 vel)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(object);
	btVector3 v = body->getLinearVelocity();
	memcpy(vel, v, sizeof(plReal) * 3);
}

void plGetAngularVelocity(plRigidBodyHandle object, plVector3 vel)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(object);
	btVector3 v = body->getAngularVelocity();
	memcpy(vel, v, sizeof(plReal) * 3);
}

plHingeConstraint plCreateConstraint(plDynamicsWorldHandle world, plRigidBodyHandle object1, plRigidBodyHandle object2)
{
	btRigidBody *body1 = reinterpret_cast< btRigidBody * >(object1);
	btAssert(body1);
	btRigidBody *body2 = reinterpret_cast< btRigidBody * >(object2);
	btAssert(body2);
	btDynamicsWorld *dynamicsWorld = reinterpret_cast< btDynamicsWorld * >(world);
	btTransform transform1, transform2;
	transform1.setIdentity();
	transform2.setIdentity();
	btScalar length1 = 0, length2 = 0;
	btCollisionShape *shape1 = body1->getCollisionShape(), *shape2 = body2->getCollisionShape();

	if (shape1->getShapeType() == BOX_SHAPE_PROXYTYPE)
	{
		length1 = ((btBoxShape *)shape1)->getHalfExtentsWithMargin().getZ();
	}

	if (shape2->getShapeType() == BOX_SHAPE_PROXYTYPE)
	{
		length2 = ((btBoxShape *)shape2)->getHalfExtentsWithMargin().getZ();
	}

	transform1.setOrigin(btVector3(0, 0, -length1));
	transform2.setOrigin(btVector3(0, 0, length2));
	btHingeConstraint *constraint = new btHingeConstraint(*body1, *body2, transform1, transform2);
	constraint->setLimit(0, 0, 1, .3, 1);
	dynamicsWorld->addConstraint(constraint, true);
	return (plHingeConstraint) constraint;
}

void plSetConstraintTransform(plHingeConstraint constraintH, plQuaternion quat)
{
	btHingeConstraint *constraint = reinterpret_cast< btHingeConstraint * >(constraintH);
	btQuaternion orn(quat[1], quat[2], quat[3], quat[3]);
	constraint->getAFrame().setRotation(orn);
}

void plSetConstraintOrigin(plHingeConstraint constraintH, plVector3 pos)
{
	btHingeConstraint *constraint = reinterpret_cast< btHingeConstraint * >(constraintH);
	btVector3 p(tobtvec3(pos));
	constraint->getAFrame().setOrigin(p);
}

void plGetConstraintOrigin(plHingeConstraint constraintH, plVector3 pos)
{
	btHingeConstraint *constraint = reinterpret_cast< btHingeConstraint * >(constraintH);
	btVector3 p =	constraint->getAFrame().getOrigin();
	memcpy(pos, p, sizeof(plReal) * 3);
}

void plSetOrientation(plRigidBodyHandle object, const plQuaternion orientation)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(object);
	btAssert(body);
	btQuaternion orn(orientation[0], orientation[1], orientation[2], orientation[3]);
	btTransform worldTrans = body->getWorldTransform();
	worldTrans.setRotation(orn);
	body->setWorldTransform(worldTrans);
}

void plSetDamping(plRigidBodyHandle object, plReal linDamping, plReal angDamping)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(object);
	btAssert(body);
	body->setDamping(linDamping, angDamping);
}

void plSetRestitution(plRigidBodyHandle object, plReal restitution)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(object);
	btAssert(body);
	body->setRestitution(restitution);
}

PLPROTO void plSetMassProps(plRigidBodyHandle object, plReal mass)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(object);
	btAssert(body);
	body->setMassProps(mass, btVector3(0, 0, 0));
}

void plSetGravity(plRigidBodyHandle object, plReal gravity)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(object);
	btAssert(body);
	body->setGravity(btVector3(gravity, gravity, gravity));
}

void plSetLinVelocity(plRigidBodyHandle object, plReal vel)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(object);
	btAssert(body);
	body->setLinearVelocity(btVector3(0, vel, 0));
}

void	plGetOpenGLMatrix(plRigidBodyHandle object, plReal *matrix)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(object);
	btAssert(body);
	body->getWorldTransform().getOpenGLMatrix(matrix);
}

void	plGetPosition(plRigidBodyHandle object, plVector3 position)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(object);
	btAssert(body);
	const btVector3 &pos = body->getWorldTransform().getOrigin();
	position[0] = pos.getX();
	position[1] = pos.getY();
	position[2] = pos.getZ();
}

void plGetSize(plRigidBodyHandle object, plReal &width, plReal &height, plReal &length)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(object);
	btAssert(body);
	btCollisionShape *cShape = body->getCollisionShape();

	if (cShape->getShapeType() == BOX_SHAPE_PROXYTYPE)
	{
		btVector3 vec = ((btBoxShape *)cShape)->getHalfExtentsWithMargin();
		width = vec.getX() * 2;
		height = vec.getY() * 2;
		length = vec.getZ() * 2;
	}
	else if (cShape->getShapeType() == SPHERE_SHAPE_PROXYTYPE)
	{
		width = height = length = ((btSphereShape *)cShape)->getRadius() * 2;
	}
	else if (cShape->getShapeType() == TERRAIN_SHAPE_PROXYTYPE)
	{
		width = height = length = 1;
	}
}

void plGetOrientation(plRigidBodyHandle object, plQuaternion orientation)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(object);
	btAssert(body);
	const btQuaternion &orn = body->getWorldTransform().getRotation();
	orientation[0] = orn.getX();
	orientation[1] = orn.getY();
	orientation[2] = orn.getZ();
	orientation[3] = orn.getW();
}


/*void pl_RigidBody_getRelPosition(plRigidBodyHandle object, const plReal* relPos, plReal* worldPos)
{
	btRigidBody* body = reinterpret_cast< btRigidBody* >(object);
	btAssert(body);

	if (body && body->getMotionState())
	{
		btDefaultMotionState* myMotionState = (btDefaultMotionState*)body->getMotionState();
		memcpy(worldPos, &(myMotionState->m_graphicsWorldTrans * btVector3(relPos)), sizeof(plReal) * 3);
	}
	else
	{
		memcpy(worldPos, &( body->getWorldTransform()* btVector3(relPos)), sizeof(plReal) * 3);
	}
}*/

void pl_RigidBody_setWorldTransform(plRigidBodyHandle object, const btTransform *transform)
{
	btRigidBody *body = reinterpret_cast< btRigidBody * >(object);
	btAssert(body);
	body->setWorldTransform(*transform);
}

PLPROTO int plClosestRayCast(plDynamicsWorldHandle world, const plVector3 &rayStart, const plVector3 &rayEnd, plRayCastResult &res)
{
	btDynamicsWorld *dynamicsWorld = reinterpret_cast<btDynamicsWorld *>(world);
	btCollisionWorld::ClosestRayResultCallback resultCallback(tobtvec3(rayStart), tobtvec3(rayEnd));
	dynamicsWorld->rayTest(tobtvec3(rayStart), tobtvec3(rayEnd), resultCallback);

	if (resultCallback.hasHit())
	{
		res.m_body = (plRigidBodyHandle)resultCallback.m_collisionObject;
		res.m_shape = (plCollisionShapeHandle)resultCallback.m_collisionObject->getCollisionShape();
		memcpy(res.m_positionWorld, &(resultCallback.m_hitPointWorld),  sizeof(plReal) * 3);
		memcpy(res.m_normalWorld,   &(resultCallback.m_hitNormalWorld), sizeof(plReal) * 3);
		return 1;
	}

	return 0; // no results
}

//plRigidBodyHandle plRayCast(plDynamicsWorldHandle world, const plVector3 rayStart, const plVector3 rayEnd, plVector3 hitpoint, plVector3 normal)
//	 plRigidBodyHandle plObjectCast(plDynamicsWorldHandle world, const plVector3 rayStart, const plVector3 rayEnd, plVector3 hitpoint, plVector3 normal);

//	extern  plRigidBodyHandle plObjectCast(plDynamicsWorldHandle world, const plVector3 rayStart, const plVector3 rayEnd, plVector3 hitpoint, plVector3 normal);

// fixme: not compatible with BT_USE_DOUBLE_PRECISION
#if 0
double plNearestPoints(float p1[3], float p2[3], float p3[3], float q1[3], float q2[3], float q3[3], float *pa, float *pb, float normal[3])
{
#ifdef BT_USE_DOUBLE_PRECISION
	DebugBreak();   // It says not compatible..... Dunno how to make it compatible though..
	return -1.0f;
#else
	btVector3 vp(p1[0], p1[1], p1[2]);
	btTriangleShape trishapeA(vp,
							  btVector3(p2[0], p2[1], p2[2]),
							  btVector3(p3[0], p3[1], p3[2]));
	trishapeA.setMargin(0.000001f);
	btVector3 vq(q1[0], q1[1], q1[2]);
	btTriangleShape trishapeB(vq,
							  btVector3(q2[0], q2[1], q2[2]),
							  btVector3(q3[0], q3[1], q3[2]));
	trishapeB.setMargin(0.000001f);
	// btVoronoiSimplexSolver sGjkSimplexSolver;
	// btGjkEpaPenetrationDepthSolver penSolverPtr;
	static btSimplexSolverInterface sGjkSimplexSolver;
	sGjkSimplexSolver.reset();
	static btGjkEpaPenetrationDepthSolver Solver0;
	static btMinkowskiPenetrationDepthSolver Solver1;
	btConvexPenetrationDepthSolver *Solver = NULL;
	Solver = &Solver1;
	btGjkPairDetector convexConvex(&trishapeA , &trishapeB, &sGjkSimplexSolver, Solver);
	convexConvex.m_catchDegeneracies = 1;
	// btGjkPairDetector convexConvex(&trishapeA ,&trishapeB,&sGjkSimplexSolver,0);
	btPointCollector gjkOutput;
	btGjkPairDetector::ClosestPointInput input;
	btStackAlloc gStackAlloc(1024 * 1024 * 2);
	input.m_stackAlloc = &gStackAlloc;
	btTransform tr;
	tr.setIdentity();
	input.m_transformA = tr;
	input.m_transformB = tr;
	convexConvex.getClosestPoints(input, gjkOutput, 0);

	if (gjkOutput.m_hasResult)
	{
		pb[0] = pa[0] = gjkOutput.m_pointInWorld[0];
		pb[1] = pa[1] = gjkOutput.m_pointInWorld[1];
		pb[2] = pa[2] = gjkOutput.m_pointInWorld[2];
		pb[0] += gjkOutput.m_normalOnBInWorld[0] * gjkOutput.m_distance;
		pb[1] += gjkOutput.m_normalOnBInWorld[1] * gjkOutput.m_distance;
		pb[2] += gjkOutput.m_normalOnBInWorld[2] * gjkOutput.m_distance;
		normal[0] = gjkOutput.m_normalOnBInWorld[0];
		normal[1] = gjkOutput.m_normalOnBInWorld[1];
		normal[2] = gjkOutput.m_normalOnBInWorld[2];
		return gjkOutput.m_distance;
	}

	return -1.0f;
#endif // BT_USE_DOUBLE_PRECISION
}
#endif // Used by Blender only
