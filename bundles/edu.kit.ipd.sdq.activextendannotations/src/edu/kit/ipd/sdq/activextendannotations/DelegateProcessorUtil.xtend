package edu.kit.ipd.sdq.activextendannotations

import org.eclipse.xtend.lib.macro.TransformationContext
import org.eclipse.xtend.lib.macro.declaration.MutableClassDeclaration
import org.eclipse.xtend.lib.macro.declaration.ResolvedMethod
import org.eclipse.xtend.lib.macro.declaration.TypeReference
import java.util.Map

// TODO MK if active annotation for static delegation is added to Xtend then
// merge all code of this class with org.eclipse.xtend.lib.annotations.DelegateProcessor$Util
class DelegateProcessorUtil {
	extension TransformationContext context

	new(TransformationContext context) {
		this.context = context
	}
	
	def implementMethod(MutableClassDeclaration delegate, String delegationTargetName, ResolvedMethod resolvedMethod) {
		delegate.markAsRead
		val declaration = resolvedMethod.declaration
		delegate.addMethod(declaration.simpleName) [ impl |
			impl.primarySourceElement = delegate.primarySourceElement
			val typeParameterMappings = newHashMap
			resolvedMethod.resolvedTypeParameters.forEach[param|
				val copy = impl.addTypeParameter(param.declaration.simpleName, param.resolvedUpperBounds)
				typeParameterMappings.put(param.declaration.newTypeReference, copy.newTypeReference)
				copy.upperBounds = copy.upperBounds.map[replace(typeParameterMappings)]
			]
			impl.exceptions = resolvedMethod.resolvedExceptionTypes.map[replace(typeParameterMappings)]
			impl.varArgs = declaration.varArgs
			impl.returnType = resolvedMethod.resolvedReturnType.replace(typeParameterMappings)
			resolvedMethod.resolvedParameters.forEach[p|impl.addParameter(p.declaration.simpleName, p.resolvedType.replace(typeParameterMappings))]
			// BEGIN MK adapt for static delegation
			impl.body = '''
				«if (impl.returnType.void) "" else "return "»«delegationTargetName».«declaration.simpleName»(«declaration.parameters.join(", ")[simpleName]»);
			'''
			impl.static = resolvedMethod.declaration.static
			// END MK adapt for static delegation
		]
	}
	
	def TypeReference replace(TypeReference target, Map<? extends TypeReference, ? extends TypeReference> mappings) {
		mappings.entrySet.fold(target)[result, mapping|result.replace(mapping.key, mapping.value)]
	}
	
	def TypeReference replace(TypeReference target, TypeReference oldType, TypeReference newType) {
		if (target == oldType)
			return newType
		if (!target.actualTypeArguments.isEmpty)
			// BEGIN MK fix null issue occurring at IterableXOCLExtensions.flatten
			if (target.type != null) {
				return newTypeReference(target.type, target.actualTypeArguments.map[replace(oldType, newType)])
			}
			// END MK fix null issue occurring at IterableXOCLExtensions.flatten
		if (target.wildCard) {
			if (target.upperBound != object)
				return target.upperBound.replace(oldType, newType).newWildcardTypeReference
			else if (!target.lowerBound.isAnyType)
				return target.lowerBound.replace(oldType, newType).newWildcardTypeReferenceWithLowerBound
		}
		if (target.isArray)
			return target.arrayComponentType.replace(oldType, newType).newArrayTypeReference
		return target
	}
}