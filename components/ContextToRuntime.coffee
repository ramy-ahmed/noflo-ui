noflo = require 'noflo'

sendContext = (context) ->
  if context.project
    sendProject context.project, context.runtime
    return

  if context.graphs?.length
    sendGraph graph, context.runtime for graph in context.graphs
    return

sendProject = (project, runtime) ->
  if project.components
    sendComponent component, runtime for component in project.components
  if project.graphs
    sendGraph graph, runtime, project for graph in project.graphs

sendComponent = (component, runtime) ->
  return unless component.code

  # Check for platform-specific components
  runtimeType = component.code.match /@runtime ([a-z\-]+)/
  if runtimeType and runtimeType[1] isnt runtime.definition.type
    return

  runtime.sendComponent 'source',
    name: component.name
    language: component.language
    library: component.project or component.library
    code: component.code
    tests: component.tests

sendGraph = (graph, runtime, project) ->
  if graph.properties.environment?.type
    if graph.properties.environment.type isnt 'all' and graph.properties.environment.type isnt runtime.definition.type
      return

  runtime.sendGraph 'clear',
    id: graph.properties.id or graph.name
    name: graph.name
    library: graph.properties.project
    main: (not project or graph.properties.id is project.main)
  for node in graph.nodes
    runtime.sendGraph 'addnode',
      id: node.id
      component: node.component
      metadata: node.metadata
      graph: graph.properties.id
  for edge in graph.edges
    runtime.sendGraph 'addedge',
      src:
        node: edge.from.node
        port: edge.from.port
      tgt:
        node: edge.to.node
        port: edge.to.port
      metadata: edge.metadata
      graph: graph.properties.id
  for iip in graph.initializers
    runtime.sendGraph 'addinitial',
      src:
        data: iip.from.data
      tgt:
        node: iip.to.node
        port: iip.to.port
      metadata: iip.metadata
      graph: graph.properties.id
  if graph.inports
    for pub, priv of graph.inports
      runtime.sendGraph 'addinport',
        public: pub
        node: priv.process
        port: priv.port
        graph: graph.properties.id
  if graph.outports
    for pub, priv of graph.outports
      runtime.sendGraph 'addoutport',
        public: pub
        node: priv.process
        port: priv.port
        graph: graph.properties.id

exports.getComponent = ->
  c = new noflo.Component
  c.inPorts.add 'context',
    datatype: 'object'
    process: (event, payload) ->
      return unless event is 'data'
      return unless payload.runtime
      sendContext payload

      return unless payload.runtime.definition.protocol is 'iframe'
      payload.runtime.on 'connected', ->
        sendContext payload

  c
