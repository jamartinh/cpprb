# distutils: language = c++

from SegmentTree cimport SegmentTree as cppSegmentTree

class SegmentTree:
    def __init__(self):
        print("Segment Tree")

if __name__ is "main":
    sg = SegmentTree()
