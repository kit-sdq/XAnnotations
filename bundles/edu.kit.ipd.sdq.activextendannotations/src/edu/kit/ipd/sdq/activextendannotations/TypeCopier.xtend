package edu.kit.ipd.sdq.activextendannotations

import org.eclipse.xtend.lib.macro.declaration.MutableMethodDeclaration
import org.eclipse.xtend.lib.macro.declaration.ResolvedMethod
import org.eclipse.xtend.lib.macro.declaration.TypeReference
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtend.lib.macro.TransformationContext
import java.util.HashMap
import org.eclipse.xtend.lib.macro.declaration.TypeParameterDeclarator
import org.eclipse.xtend.lib.macro.declaration.MutableTypeParameterDeclarator
import org.eclipse.xtend.lib.macro.declaration.TypeParameterDeclaration
import java.util.List

/**
 * Helper to copy types from one Java element to another. Copying types is
 * straightforward a long as no type parameters are involved. However,
 * <em>if</em> type parameters are involved, they need to be copied and any
 * reference to a type parameter needs to be replaced with its copy. This is
 * handled by this class.
 * 
 * <p>A new instance of this class must be created for every element types are
 * to be copied to. If there is a parent scope from which type parameters could
 * be inherited, the copier for the parent scope must be passed in as parent.
 */
@FinalFieldsConstructor
class TypeCopier {

	val typeParameterMappings = new HashMap<TypeReference, TypeReference>
	val extension TransformationContext context
	
	new(TypeCopier parent, TransformationContext context) {
		this(context)
		typeParameterMappings += parent.typeParameterMappings	
	}
	
	/**
	 * Copies all type parameters that appear in the {@code source} type reference to
	 * the {@code target} type declaration. Afterwards, this copier can be used to replace
	 *  type parameters that come from {@code source} and are used in {@code target}.
	 */
	def copyTypeParametersFrom(MutableTypeParameterDeclarator target, TypeReference source) {
		val sourceType = source.type
		if (sourceType instanceof TypeParameterDeclarator) {
			val actualTypeParameters = source.actualTypeArguments.iterator
			source.allReferencedTypeVariables.forEach [ param |
				if (!typeParameterMappings.containsKey(param)) {
					val copy = target.addTypeParameter(param.simpleName, param.upperBounds)
					typeParameterMappings.put(param.newTypeReference, copy.newTypeReference)
					copy.upperBounds = copy.upperBounds.map[replaceTypeParameters]
				}
			]
			sourceType.typeParameters.forEach [ param |
				val actualType = actualTypeParameters.next
				typeParameterMappings.put(param.newTypeReference, actualType.replaceTypeParameters())
			]
		}
	}

	/**
	 * Copies all type parameters from the {@code source} method to the 
	 * {@code target} method. Afterwards, this copier can be used to replace
	 *  type parameters that come from {@code source} and are used in {@code target}.
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
	 * {@code target} method. Afterwards, this copier can be used to replace
	 *  type parameters that come from {@code source} and are used in {@code target}.
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
	
	def private Iterable<TypeParameterDeclaration> getAllReferencedTypeVariables(TypeReference source) {
		val sourceType = source.type
		if (sourceType instanceof TypeParameterDeclaration) {
			List.of(sourceType)
		} else if (source.isWildCard) {
			(if (source.upperBound != object) {
				source.upperBound.allReferencedTypeVariables
			} else emptyList()) 
			 + (if (!source.lowerBound.isAnyType) {
			 	source.lowerBound.allReferencedTypeVariables
			 } else emptyList())
		} else if (source.isArray) {
			source.arrayComponentType.allReferencedTypeVariables
		} else {
			source.actualTypeArguments.flatMap[allReferencedTypeVariables]
		}
	}
}
