package edu.kit.ipd.sdq.activextendannotations

import org.eclipse.xtend.lib.macro.declaration.MutableMethodDeclaration
import org.eclipse.xtend.lib.macro.declaration.ResolvedMethod
import org.eclipse.xtend.lib.macro.declaration.TypeReference
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtend.lib.macro.TransformationContext
import java.util.HashMap

/**
 * Helper to copy types from one method to another. Copying types is
 * straightforward a long as no type parameters are involved. However,
 * <em>if</em> type parameters are involved, they need to be copied and any
 * reference to a type parameter needs to be replaced with its copy. This is
 * handled by this class.
 * 
 * <p>A new instance of this class must be created for every method types are
 * to be copied to.
 */
@FinalFieldsConstructor
class TypeCopier {

	val typeParameterMappings = new HashMap<TypeReference, TypeReference>
	val extension TransformationContext context

	/**
	 * Copies all type parameters from the {@code source} method to the 
	 * {@code target} method. The class can be used to replace type parameters
	 * in type reference afterwards. 
	 * 
	 * @param target The method declaration to copy the type parameters to.
	 * @param source The method declaration to copy the type parameters 
	 * from.
	 */
	def copyTypeParametersFrom(MutableMethodDeclaration target, ResolvedMethod source) {
		source.resolvedTypeParameters.forEach [ param |
			val copy = target.addTypeParameter(param.declaration.simpleName, param.resolvedUpperBounds)
			typeParameterMappings.put(param.declaration.newTypeReference, copy.newTypeReference)
			copy.upperBounds = copy.upperBounds.map[replaceTypeParameters]
		]
	}

	/**
	 * Copies all type parameters from the {@code source} method to the 
	 * {@code target} method. The class can be used to replace type parameters
	 * in type reference afterwards. 
	 * 
	 * @param target The method declaration to copy the type parameters to.
	 * @param source The method declaration to copy the type parameters 
	 * from.
	 */
	def copyTypeParametersFrom(MutableMethodDeclaration target, MutableMethodDeclaration source) {
		source.typeParameters.forEach [ param |
			val copy = target.addTypeParameter(param.simpleName, param.upperBounds)
			typeParameterMappings.put(param.newTypeReference, copy.newTypeReference)
			copy.upperBounds = copy.upperBounds.map[replaceTypeParameters]
		]
	}

	// the following two methods were copied from 
	// org.eclipse.xtend.lib.annotations.DelegateProcessor.Util
	/**
	 * Replaces references to type parameters by their copies, which were
	 * created by calling {@link copyTypeParametersFrom}. If
	 * {@link copyTypeParametersFrom} was not called or the {@code source} it
	 * was called with does not contain type parameters, the type reference
	 * will be returned unchanged.
	 * 
	 * @param target The type reference to replace type parameters in.
	 * @return An equal type reference that has all references to type
	 * 		parameters replaced by their according copies.
	 */
	def TypeReference replaceTypeParameters(TypeReference target) {
		typeParameterMappings.entrySet.fold(target)[result, mapping|result.replace(mapping.key, mapping.value)]
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
}
