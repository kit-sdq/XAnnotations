package edu.kit.ipd.sdq.activextendannotations

import java.lang.annotation.Target
import org.eclipse.xtend.lib.macro.TransformationParticipant
import java.util.List
import org.eclipse.xtend.lib.macro.TransformationContext
import org.eclipse.xtend.lib.macro.Active
import org.eclipse.xtend.lib.macro.declaration.MutableTypeDeclaration
import org.eclipse.xtend.lib.macro.declaration.MethodDeclaration
import org.eclipse.xtend.lib.macro.declaration.NamedElement
import org.eclipse.xtend.lib.macro.declaration.MutableMethodDeclaration
import java.lang.annotation.Repeatable
import org.eclipse.xtend.lib.macro.declaration.AnnotationTarget
import org.eclipse.xtend.lib.macro.declaration.Type
import org.eclipse.xtend.lib.macro.declaration.AnnotationReference
import java.util.HashSet
import java.util.Set
import java.util.ArrayList
import java.util.HashMap
import org.eclipse.xtend.lib.macro.declaration.TypeReference
import java.util.Map
import org.eclipse.xtend.lib.macro.declaration.ResolvedMethod
import org.eclipse.xtend.lib.macro.declaration.TypeDeclaration
import org.eclipse.xtend.lib.macro.declaration.MemberDeclaration
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

import static extension edu.kit.ipd.sdq.activextendannotations.VisibilityExtension.toXtendVisibility

/**
 * Adds static delegate methods to all accessible static methods of the
 * declared types. This annotation can be used multiple times on the same type
 * to export methods with different visibilities.
 */
@Target(TYPE)
@Active(ExportStaticMethodsProcessor)
@Repeatable(StaticDelegateContainer)
annotation StaticDelegate {
	/**
	 * The types whose accessible static methods shall be delegated to.
	 */
	Class<?>[] value = #[]
	/**
	 * @deprecated use {@link #value} instead
	 */
	@Deprecated Class<?>[] delegationTargets = #[]
	/**
	 * The desired visibility of the created delegation methods.
	 */
	Visibility visibility = Visibility.AS_DECLARED
}

class ExportStaticMethodsProcessor implements TransformationParticipant<MutableTypeDeclaration> {

	override doTransform(List<? extends MutableTypeDeclaration> annotatedTargetElements,
		extension TransformationContext context) {
		val extension delegateProcessor = new ContexedProcessor(context)

		for (annotatedType : annotatedTargetElements) {
			val exportAnnotations = annotatedType.findAllAnnotations(StaticDelegate.findTypeGlobally)
			val validAnnotations = exportAnnotations.checkForDuplicateTypes.checkForSelfReference(annotatedType)
			for (exportAnnotation : validAnnotations) {
				// transform for every annotation occurrence on every type
				doTransform(annotatedType, exportAnnotation)
			}
		}
	}

	/**
	 * Trick class to have the extension {@link #context}
	 */
	@FinalFieldsConstructor
	private static class ContexedProcessor {

		val extension TransformationContext context

		def private doTransform(MutableTypeDeclaration annotatedType, AnnotationReference annotation) {
			val exportedVisiblity = Visibility.valueOf(annotation.getEnumValue('visibility').simpleName)
			for (sourceType : annotation.delegationTargets.withoutDuplicateTypes) {
				val staticMethods = sourceType.declaredResolvedMethods.filter [
					declaration.static && declaration.isAccessibleFrom(annotatedType)
				]
				for (staticMethod : staticMethods) {
					annotatedType.createDelegationTo(staticMethod) [
						visibility = exportedVisiblity.toXtendVisibility(staticMethod.declaration.visibility)
					]
				}
			}
		}

		/**
		 * Creates a static delegation method to the provided `resolvedMethod`
		 * in the provided `type`. The created method will have similar
		 * properties as the delegated method, it will for example have the
		 * same comment.
		 */
		def private createDelegationTo(MutableTypeDeclaration target, ResolvedMethod resolvedMethod,
			Procedures.Procedure1<MutableMethodDeclaration> furtherInitialiser) {
			val method = resolvedMethod.declaration
			val typeParameterMappings = new HashMap<TypeReference, TypeReference>

			val copy = target.addMethod(method.simpleName) [
				copyTypeParametersFrom(resolvedMethod, typeParameterMappings)
				primarySourceElement = method.declaringType
				returnType = resolvedMethod.resolvedReturnType.replace(typeParameterMappings)
				varArgs = method.varArgs
				docComment = method.docComment
				static = true
				abstract = false
				body = '''
					«IF (!method.returnType.isVoid)»return «ENDIF»«method.declaringType».«method.simpleName»(«method.parameters.join(', ')[simpleName]»);
				'''
			]
			method.annotations.forEach[copy.addAnnotation(it)]
			resolvedMethod.resolvedParameters.forEach [
				copy.addParameter(it.declaration.simpleName, it.resolvedType.replace(typeParameterMappings))
			]
			furtherInitialiser.apply(copy)

			// add an @Inline annotation if this does not break things because
			// of visibility
			if (method.isAsVisibleAsAs(copy)) {
				val parametersLength = method.parameters.length
				copy.addAnnotation(newAnnotationReference(Inline) [
					setStringValue(
						'value', '''$«parametersLength + 1».«method.simpleName»(«FOR i : 1 .. parametersLength SEPARATOR ', '»$«i»«ENDFOR»)''')
					setClassValue('imported', method.declaringType.newTypeReference)
				])
			}
			copy
		}

		/**
		 * Copies the type parameters from the `source` method to the `target`
		 *  method while populating the provided type parameters map.
		 * 
		 * @param target The method declaration to copy the type parameters to.
		 * @param source The method declaration to copy the type parameters 
		 * from.
		 * @param typeParameterMappings A map that contains the translations
		 * from the type parameters in the old method to the type parameters
		 * in the copied method.
		 */
		def private copyTypeParametersFrom(MutableMethodDeclaration target, ResolvedMethod source,
			Map<TypeReference, TypeReference> typeParameterMappings) {
			source.resolvedTypeParameters.forEach [ param |
				val copy = target.addTypeParameter(param.declaration.simpleName, param.resolvedUpperBounds)
				typeParameterMappings.put(param.declaration.newTypeReference, copy.newTypeReference)
				copy.upperBounds = copy.upperBounds.map[replace(typeParameterMappings)]
			]
		}

		// the following two methods were copied from 
		// org.eclipse.xtend.lib.annotations.DelegateProcessor.Util
		/**
		 * Translates the the type parameters in `target` based on the provided
		 * type parameters map.
		 * 
		 * @param target The type reference to replace type parameters in.
		 * @param mappings A type parameters map that was created by
		 * {@link #copyTypeParametersFrom}.
		 */
		def private TypeReference replace(TypeReference target,
			Map<? extends TypeReference, ? extends TypeReference> mappings) {
			mappings.entrySet.fold(target)[result, mapping|result.replace(mapping.key, mapping.value)]
		}

		def private TypeReference replace(TypeReference target, TypeReference oldType, TypeReference newType) {
			if (target == oldType)
				return newType
			if (!target.actualTypeArguments.isEmpty)
				if (target.type !== null) {
					return newTypeReference(target.type, target.actualTypeArguments.map[replace(oldType, newType)])
				}
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

		/**
		 * Filters the provided type references, such that there is only on reference per type in the result.
		 * 
		 * @param references The references to process.
		 * @return A copy of the provided `references`, such that any reference referencing a type referenced by another reference is removed.
		 */
		def private withoutDuplicateTypes(TypeReference[] references) {
			val typeToRef = newHashMap
			references.forEach[typeToRef.put(it.type, it)]
			typeToRef.values
		}

		/**
		 * Checks if any of the provided annotations reference the same type.
		 * If so, adds an error to those annotations and filters them out of
		 * the result.
		 * 
		 * Additionally adds a warning if an annotation references the same
		 * type in itself, but does not filter it out.
		 * 
		 * @param annotations The {@link StaticDelegate} annotations to check
		 * @return The annotations that did not declare types that other
		 * annotations also declared
		 */
		def private checkForDuplicateTypes(Iterable<? extends AnnotationReference> annotations) {
			val validAnnotations = new ArrayList(annotations.length);
			val usedTypes = new HashMap<Type, Set<AnnotationReference>>
			for (annotation : annotations) {
				val containedDuplicates = annotation.delegationTargets.map[type].duplicates
				if (containedDuplicates.length > 0) {
					containedDuplicates.forEach [
						annotation.delegationTargetsExpression.
							addWarning('''Type «simpleName» is listet multiple times.''')
					]
				}
				val annotatedTypes = new HashSet(annotation.delegationTargets.map[type])
				val duplicates = usedTypes.keySet.intersect(annotatedTypes)
				if (duplicates.length == 0) {
					validAnnotations += annotation
				} else {
					duplicates.forEach [ type |
						(usedTypes.get(type) + #[annotation]).map[delegationTargetsExpression].forEach [
							addError('''The type «type.simpleName» is also used in another @«StaticDelegate.simpleName» annotation.''')
						]
					]
				}
				annotatedTypes.forEach [ type |
					usedTypes.computeIfPresent(type, [k, set|set += annotation; set]);
					usedTypes.putIfAbsent(type, new HashSet(#[annotation]))
				]
			}
			validAnnotations
		}

		def private checkForSelfReference(Iterable<? extends AnnotationReference> annotations,
			MutableTypeDeclaration annotatedType) {
			val validAnnotations = new ArrayList(annotations.length);
			for (annotation : annotations) {
				if (annotation.delegationTargets.map[type].contains(annotatedType)) {
					annotation.getExpression('value').
						addError('''A type cannot export its own methods. Remove the type «annotatedType.simpleName» from the list.''')
				} else {
					validAnnotations += annotation
				}
			}
			validAnnotations
		}

		/**
		 * Finds the duplicate entries in the provided `iterable`.
		 * 
		 * @param iterable The iterable to inspect
		 * @return The set of elements present at least twice in the provided
		 * `iterable`. Equality is checked based on {@link Object#equals}.
		 */
		def private static <T> duplicates(Iterable<T> iterable) {
			val seen = new HashSet<T>(iterable.length)
			val duplicates = new HashSet<T>
			for (value : iterable) {
				if (seen.contains(value)) {
					duplicates += value
				} else {
					seen += value
				}
			}
			duplicates
		}

		/**
		 * @return The instersection of `a` and `b` in a new set.
		 */
		def private static <T> intersect(Set<T> a, Set<T> b) {
			val copyOfA = new HashSet(a)
			copyOfA.retainAll(b)
			copyOfA
		}

		def private isAccessibleFrom(MethodDeclaration method, MutableTypeDeclaration type) {
			!(method.visibility == org.eclipse.xtend.lib.macro.declaration.Visibility.PRIVATE &&
				method.declaringType != type) &&
				!(method.visibility == org.eclipse.xtend.lib.macro.declaration.Visibility.DEFAULT &&
					!method.isInSamePackageAs(type))
		}

		/**
		 * Determines whether `reference` is in the same package as `thiz`
		 */
		def private isInSamePackageAs(NamedElement thiz, NamedElement reference) {
			thiz.compilationUnit.packageName == reference.compilationUnit.packageName
		}

		/**
		 * Finds all annotations of `type` on `target`.
		 * 
		 * @return All annotations of type `type` on `target`.
		 */
		def private findAllAnnotations(AnnotationTarget target, Type annotationType) {
			target.annotations.filter[annotationTypeDeclaration == annotationType]
		}

		/**
		 * Determines whether `reference` can be accessed by anybody who’s able to access `thiz`.
		 */
		def private isAsVisibleAsAs(MethodDeclaration thiz, MethodDeclaration reference) {
			reference.declaringType.isAsVisibleAs(thiz.declaringType) &&
				(reference.isPublic || thiz.isSamePackageVisible(reference))
		}

		/**
		 * Determines whether `reference` can be accessed by anybody who’s able to access `thiz`.
		 */
		def private isAsVisibleAs(TypeDeclaration thiz, TypeDeclaration reference) {
			reference.isPublic || thiz.isSamePackageVisible(reference)
		}

		/**
		 * @return `true` iff `declaration` is public.
		 */
		def private isPublic(MemberDeclaration declaration) {
			declaration.visibility == org.eclipse.xtend.lib.macro.declaration.Visibility.PUBLIC
		}

		/**
		 * Determines whether both `thiz` and `reference` are package-private *and* lie are the same package.
		 */
		def private isSamePackageVisible(MemberDeclaration thiz, MemberDeclaration reference) {
			(reference.visibility == org.eclipse.xtend.lib.macro.declaration.Visibility.DEFAULT &&
				thiz.visibility == org.eclipse.xtend.lib.macro.declaration.Visibility.DEFAULT &&
				reference.isInSamePackageAs(thiz))
		}

		/**
		 * Gets the delegation targets of a {@link StaticDelegate}
		 * declaration. Returns the `value` field unless it’s empty. Uses (the
		 * possibly also empty) `delegationTargets` field otherwise.
		 */
		def private delegationTargets(AnnotationReference annotation) {
			val value = annotation.getClassArrayValue('value')
			if (value.length > 0) value else annotation.getClassArrayValue('delegationTargets')
		}

		/**
		 * Gets the expression defining the delegation targets.
		 * 
		 * @return the expression that defines what {@link delegationTargets}
		 * returns.
		 */
		def private delegationTargetsExpression(AnnotationReference annotation) {
			val value = annotation.getClassArrayValue('value')
			if (value !== null && value.length > 0)
				annotation.getExpression('value')
			else
				annotation.getExpression('delegationTargets')
		}
	}
}
