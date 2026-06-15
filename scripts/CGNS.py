from falcor import *

def render_graph_CGNS():
    g = RenderGraph("CGNS")

    VBufferParams = {
        'samplePattern': "Center",
        'sampleCount': 1,
        'useAlphaTest': True,
        'useDOF' : False
    }

    CGNSParams = {
        'samplesPerPixel': 1,
        'enableTemporalResampling': True,
        'enableSpatialResampling': True,
        'temporalReuse': "ScatterOnly",
        'numTimePartitions': 2,
        'hybridMISOption': "Balance",
        'gatherOption': "Fast",
    }

    VBufferRT = createPass("VBufferRT", VBufferParams)
    g.addPass(VBufferRT, "VBufferRT")
    CGNS = createPass("CGNS", CGNSParams)
    g.addPass(CGNS, "CGNS")
    AccumulatePass = createPass("AccumulatePass", {'enabled': False, 'precisionMode': 'Single'})
    g.addPass(AccumulatePass, "AccumulatePass")
    ToneMapper = createPass("ToneMapper", {'autoExposure': False, 'exposureCompensation': 0.0})
    g.addPass(ToneMapper, "ToneMapper")
    FrameDumper = createPass("FrameDumper")
    g.addPass(FrameDumper, "FrameDumper")
    g.addEdge("VBufferRT.vbuffer", "CGNS.vbuffer")
    # g.addEdge("VBufferRT.viewW", "PathTracer.viewW")
    g.addEdge("VBufferRT.mvec", "CGNS.mvec")
    g.addEdge("CGNS.color", "AccumulatePass.input")
    g.addEdge("AccumulatePass.output", "ToneMapper.src")
    # g.markOutput("ToneMapper.dst")
    g.addEdge("ToneMapper.dst", "FrameDumper.src")
    g.markOutput("FrameDumper.dst")
    g.markOutput("AccumulatePass.output")
    return g

CGNS = render_graph_CGNS()
try: m.addGraph(CGNS)
except NameError: None
