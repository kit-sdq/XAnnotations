package edu.kit.ipd.sdq.activextendannotations

import org.eclipse.xtend.lib.macro.AbstractClassProcessor
import org.eclipse.xtend.lib.macro.declaration.MutableClassDeclaration
import org.eclipse.xtend.lib.macro.TransformationContext
import org.eclipse.xtend.lib.macro.declaration.TypeReference
import org.eclipse.xtend.lib.macro.declaration.TypeDeclaration
import org.eclipse.xtend.lib.macro.declaration.Visibility

class StaticDelegateProcessor extends AbstractClassProcessor {
	
	override doTransform(MutableClassDeclaration annotatedClass, extension TransformationContext context) {
		val delegateProcessorUtil = new DelegateProcessorUtil(context)
		val annotation = annotatedClass.findAnnotation(StaticDelegate.findTypeGlobally)
		val delegationTargets = annotation.getValue("delegationTargets")
		if (delegationTargets instanceof TypeReference[]) {
			for (delegationTarget : delegationTargets) {
				if (delegationTarget.type instanceof TypeDeclaration) {
					val methodsToDelegate = delegationTarget.declaredResolvedMethods.filter[declaration.static && declaration.visibility != Visibility.PRIVATE]
					for (methodToDelegate : methodsToDelegate) {
						delegateProcessorUtil.implementMethod(annotatedClass, delegationTarget.type.qualifiedName, methodToDelegate)
					}
				} else {
					addError(annotatedClass, "Only methods of type declarations can be delegated!")
				}
			}
		}
	}
	
}