package de.wwu.md2.framework.generator.ios.controller

import de.wwu.md2.framework.generator.ios.util.GeneratorUtil
import de.wwu.md2.framework.generator.util.DataContainer
import java.lang.invoke.MethodHandles
import de.wwu.md2.framework.mD2.WorkflowEvent

class IOSWorkflowEvent {
	
	static def generateClass(DataContainer data) {
		val events = data.workflow.workflowElementEntries.map [wfe | 
			wfe.firedEvents.map [ event | 
			 	event.event		
		 	].toList
		].flatten
			 
		return generateClassContent(events)
	}
	
	static def generateClassContent(Iterable<WorkflowEvent> workflowEvents) '''
«GeneratorUtil.generateClassHeaderComment("WorkflowEvent", MethodHandles.lookup.lookupClass)»

// Make visible to Objective-C to allow use as Dictionary key (e.g. in WorkflowEventHandler)
@objc
enum WorkflowEvent: Int {
	«FOR i : 1..workflowEvents.length»
	case «workflowEvents.get(i - 1).name» = «i»
    «ENDFOR»
    
    var description: String {
        switch self {
        «FOR i : 1..workflowEvents.length»
        case .«workflowEvents.get(i - 1).name»: return "«workflowEvents.get(i - 1).name»"
    	«ENDFOR»
    	default: return "NotFound"
        }
    }
}
	'''
}