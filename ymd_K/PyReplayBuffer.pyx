# distutils: language = c++

from libc.stdlib cimport malloc, free
from cython.operator cimport dereference
cimport numpy as np
import numpy as np

from ymd_K cimport ReplayBuffer

cdef class VectorWrapper:
    cdef Py_ssize_t *shape
    cdef Py_ssize_t *strides
    cdef Py_ssize_t itemsize
    cdef int ndim
    cdef int value_dim

    def __cinit__(self):
        self.shape   = <Py_ssize_t*>malloc(sizeof(Py_ssize_t) * 2)
        self.strides = <Py_ssize_t*>malloc(sizeof(Py_ssize_t) * 2)

    def __dealloc__(self):
        free(self.shape)
        free(self.strides)

    cdef void update_size(self):
        self.shape[0] = <Py_ssize_t>(self.vec_size()//self.value_dim)
        self.strides[self.ndim -1] = <Py_ssize_t> self.itemsize

        if self.ndim is 2:
            self.shape[1] = <Py_ssize_t> (self.value_dim)
            self.strides[0] = self.value_dim * <Py_ssize_t> self.itemsize

    cdef void set_buffer(self,Py_buffer *buffer):
        pass

    def __getbuffer__(self, Py_buffer *buffer, int flags):
        # relevant documentation http://cython.readthedocs.io/en/latest/src/userguide/buffer.html#a-matrix-class

        self.update_size()

        self.set_buffer(buffer)
        buffer.len = self.vec_size() * self.itemsize
        buffer.readonly = 0
        buffer.ndim = self.ndim
        buffer.shape = self.shape
        buffer.strides = self.strides
        buffer.suboffsets = NULL
        buffer.itemsize = self.itemsize
        buffer.internal = NULL
        buffer.obj = self

    def __releasebuffer__(self, Py_buffer *buffer):
        pass

cdef class VectorInt(VectorWrapper):
    cdef vector[int] vec

    def __cinit__(self,value_dim=1):
        self.vec = vector[int]()
        self.itemsize = sizeof(int)

        self.ndim = 1 if value_dim is 1 else 2
        self.value_dim = value_dim

    def vec_size(self):
        return self.vec.size()

    cdef void set_buffer(self,Py_buffer* buffer):
        buffer.buf = <void*>(self.vec.data())
        buffer.format = 'i'

cdef class VectorDouble(VectorWrapper):
    cdef vector[double] vec

    def __cinit__(self,value_dim=1):
        self.vec = vector[double]()
        self.itemsize = sizeof(double)

        self.ndim = 1 if value_dim is 1 else 2
        self.value_dim = value_dim

    def vec_size(self):
        return self.vec.size()

    cdef void set_buffer(self,Py_buffer* buffer):
         buffer.buf = <void*>(self.vec.data())
         buffer.format = 'd'

cdef class VectorULong(VectorWrapper):
    cdef vector[size_t] vec

    def __cinit__(self,value_dim=1):
        self.vec = vector[size_t]()
        self.itemsize = sizeof(size_t)

        self.ndim = 1 if value_dim is 1 else 2
        self.value_dim = value_dim

    def vec_size(self):
        return self.vec.size()

    cdef void set_buffer(self,Py_buffer* buffer):
        buffer.buf = <void*>(self.vec.data())
        buffer.format = 'L'

cdef class PyReplayBuffer:
    cdef ReplayBuffer[double,double,double,int] *thisptr
    cdef VectorDouble obs
    cdef VectorDouble act
    cdef VectorDouble rew
    cdef VectorDouble next_obs
    cdef VectorInt done
    def __cinit__(self,size,obs_dim,act_dim):
        print("Replay Buffer")

        self.thisptr = new ReplayBuffer[double,double,double,int](size,
                                                                  obs_dim,
                                                                  act_dim)
        self.obs = VectorDouble(obs_dim)
        self.act = VectorDouble(act_dim)
        self.rew = VectorDouble()
        self.next_obs = VectorDouble(obs_dim)
        self.done = VectorInt()

    @cython.boundscheck(False)
    @cython.wraparound(False)
    def add(self,
            np.ndarray[double, ndim=2, mode="c"] obs not None,
            np.ndarray[double, ndim=2, mode="c"] act not None,
            np.ndarray[double, ndim=1, mode="c"] rew not None,
            np.ndarray[double, ndim=2, mode="c"] next_obs not None,
            np.ndarray[double, ndim=1, mode="c"] done not None,
            N=1):
        self.thisptr.add(&obs[0,0],&act[0,0],&rew[0],&next_obs[0,0],&done[0],N)

    def sample(self,size):
        self.thisptr.sample(size,
                            self.obs.vec,
                            self.act.vec,
                            self.rew.vec,
                            self.next_obs.vec,
                            self.done.vec)
        return {'obs': np.asarray(self.obs),
                'act': np.asarray(self.act),
                'rew': np.asarray(self.rew),
                'next_obs': np.asarray(self.next_obs),
                'done': np.asarray(self.done)}

cdef class PyPrioritizedReplayBuffer:
    cdef PrioritizedReplayBuffer[double,double,double,int,double] *thisptr
    cdef VectorDouble obs
    cdef VectorDouble act
    cdef VectorDouble rew
    cdef VectorDouble next_obs
    cdef VectorInt done
    cdef VectorDouble weights
    cdef VectorULong indexes
    def __cinit__(self,size,alpha,obs_dim,act_dim):
        print("Prioritized Replay Buffer")

        self.thisptr = new PrioritizedReplayBuffer[double,double,
                                                   double,int,double](size,
                                                                      obs_dim,
                                                                      act_dim,
                                                                      alpha)
        self.obs = VectorDouble(obs_dim)
        self.act = VectorDouble(act_dim)
        self.rew = VectorDouble()
        self.next_obs = VectorDouble(obs_dim)
        self.done = VectorInt()
        self.weights = VectorDouble()
        self.indexes = VectorULong()

    @cython.boundscheck(False)
    @cython.wraparound(False)
    def add(self,
            np.ndarray[double, ndim=2, mode="c"] obs not None,
            np.ndarray[double, ndim=2, mode="c"] act not None,
            np.ndarray[double, ndim=1, mode="c"] rew not None,
            np.ndarray[double, ndim=2, mode="c"] next_obs not None,
            np.ndarray[double, ndim=1, mode="c"] done not None,
            N=1):
        self.thisptr.add(&obs[0,0],&act[0,0],&rew[0],&next_obs[0,0],&done[0],N)

    def sample(self,size,beta):
        self.thisptr.sample(size,beta,
                            self.obs.vec,
                            self.act.vec,
                            self.rew.vec,
                            self.next_obs.vec,
                            self.done.vec,
                            self.weights.vec,
                            self.indexes.vec)
        return {'obs': np.asarray(self.obs),
                'act': np.asarray(self.act),
                'rew': np.asarray(self.rew),
                'next_obs': np.asarray(self.next_obs),
                'done': np.asarray(self.done),
                'weights': np.asarray(self.indexes),
                'indexes': np.asarray(self.weights)}

    def update_priorities(self,indexes,priorities):
        self.thisptr.update_priorities(indexes,priorities)
