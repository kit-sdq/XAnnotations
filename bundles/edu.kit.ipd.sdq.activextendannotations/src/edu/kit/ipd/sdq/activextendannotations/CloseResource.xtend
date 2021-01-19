package edu.kit.ipd.sdq.activextendannotations

import org.eclipse.xtend.lib.macro.Active
import java.lang.annotation.Target
import org.eclipse.xtend.lib.macro.TransformationParticipant
import org.eclipse.xtend.lib.macro.declaration.MutableParameterDeclaration
import java.util.List
import org.eclipse.xtend.lib.macro.TransformationContext
import org.eclipse.xtend.lib.macro.declaration.MutableMethodDeclaration
import org.eclipse.xtend.lib.macro.declaration.Visibility
import org.eclipse.xtend.lib.macro.declaration.MutableExecutableDeclaration
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtend.lib.macro.declaration.MutableConstructorDeclaration
import org.eclipse.xtend.lib.macro.declaration.ResolvedMethod
import org.eclipse.xtend.lib.macro.ValidationParticipant
import org.eclipse.xtend.lib.macro.ValidationContext
import org.eclipse.xtend.lib.macro.declaration.TypeReference
import java.util.Set
import org.eclipse.xtend.lib.macro.services.TypeReferenceProvider

/**
 * Allows to declare method parameters as resources that will be closed when
 * the method exits, no matter if it exits normally or by throwing an
 * exception. Xtend does not support Java’s try with resources, so this
 * annotation is a replacement until proper support is implemented. Instead of
 * using a {@code try} block, the resources are declared in the method
 * parameters using this extension. The method’s body will then wrapped in a
 * try with resources block.
 * 
 * <p>Annotated parameters must implements {@link AutoCloseable}.
 * 
 * <p>Methods having parameters using this annotation must declare a return
 * type due to a limitation in Xtend’s type inference system.
 * 
 * @see {@link https://bugs.eclipse.org/bugs/show_bug.cgi?id=366020}
 * @author Joshua Gleitze
 */
@Active(CloseResourceProcessor)
@Target(PARAMETER)
annotation CloseResource {
}

class CloseResourceProcessor implements TransformationParticipant<MutableParameterDeclaration>, ValidationParticipant<MutableParameterDeclaration> {

	override doTransform(List<? extends MutableParameterDeclaration> annotatedTargetElements,
		extension TransformationContext context) {
		val grouped = annotatedTargetElements.groupBy[declaringExecutable]
		for (annotationEntry : grouped.entrySet) {
			new CloseResourceExecutableProcessor(context).tranform(annotationEntry.key, annotationEntry.value)
		}
	}

	@FinalFieldsConstructor
	private static class CloseResourceExecutableProcessor {
		var MutableExecutableDeclaration oldExecutable
		var List<MutableParameterDeclaration> annotatedParameters
		var MutableExecutableDeclaration newExecutable
		var boolean doesReturn
		val extension TransformationContext context
		var extension TypeCopier typeCopier

		
		/**
		 * Transforms the given {@code executable}.
		 *
		 * @param executable
		 * 		The executable to transform
		 * @param annotatedParameters
		 * 		The subset of the {@code executable}’s parameters that is
		 * 		annotated with {@code TryResource}.
		 */
		def tranform(MutableExecutableDeclaration executable,
			List<MutableParameterDeclaration> annotatedParameters) {
			this.annotatedParameters = annotatedParameters
			val type = executable.declaringType

			switch (executable) {
				MutableMethodDeclaration: {
					if (executable.returnType.isInferred) {
						executable.addError('''A method using @«CloseResource.simpleName» must declare its return type''')
						return
					}
					val newMethod = type.addMethod('''_«executable.simpleName»_with_safe_resources''')[]
					withMethod(newMethod, executable)
				}
				MutableConstructorDeclaration: {
					val newConstructor = type.addConstructor[]
					withConstructor(newConstructor, executable)
				}
				default:
					throw new AssertionError("Unknown subclass of MutableExecutableDeclration")
			}

			transform()
		}

		def withMethod(MutableMethodDeclaration newMethod, MutableMethodDeclaration oldMethod) {
			typeCopier = new TypeCopier(context)
			newMethod => [
				copyTypeParametersFrom(oldMethod)
				primarySourceElement = oldMethod
				static = oldMethod.static
				final = oldMethod.final
				returnType = oldMethod.returnType.replaceTypeParameters
			]
			doesReturn = !oldMethod.returnType.isVoid
			newExecutable = newMethod
			oldExecutable = oldMethod
		}

		def withConstructor(MutableConstructorDeclaration constructor, MutableConstructorDeclaration oldConstructor) {
			typeCopier = new TypeCopier(context)
			constructor => [
				primarySourceElement = oldConstructor
			]
			newExecutable = constructor
			oldExecutable = oldConstructor
			doesReturn = false
		}

		def transform() {
			val extension info = new TypeInfo(context)
			
			newExecutable => [
				visibility = Visibility.PRIVATE
				body = oldExecutable.body
				docComment = oldExecutable.docComment
				varArgs = oldExecutable.isVarArgs
				exceptions = oldExecutable.exceptions.map[replaceTypeParameters]
			]
			oldExecutable.parameters.forEach[newExecutable.addParameter(simpleName, type.replaceTypeParameters)]

			// closing might throw exceptions -> declare them on the method
			val closeExceptions = annotatedParameters
				.map [type.withAllSuperTypes]
				.map[map[declaredResolvedMethods.filter(ResolvedMethod).findFirst [simpleSignature == 'close()']].findFirst [it !== null]]
				.filter [it !== null]
				.map[resolvedExceptionTypes].flatten
			oldExecutable.exceptions = (oldExecutable.exceptions + closeExceptions).toSet

			oldExecutable.body = '''
				try («FOR p : annotatedParameters SEPARATOR '; '»«p.type» r_«p.simpleName» = «p.simpleName»«ENDFOR») {
					«IF doesReturn»return «ENDIF»«newExecutable.simpleName»(«FOR p : oldExecutable.parameters SEPARATOR ', '»«IF p.isAnnotated»r_«ENDIF»«p.simpleName»«ENDFOR»);
				}			
			'''
			oldExecutable.docComment = ''
		}

		def isAnnotated(MutableParameterDeclaration parameter) {
			return annotatedParameters.contains(parameter)
		}
	}

	override doValidate(List<? extends MutableParameterDeclaration> annotatedTargetElements,
		extension ValidationContext context) {
		val extension info = new TypeInfo(context)
		for (parameter : annotatedTargetElements) {
			if (!parameter.type.hasSuperType(AutoCloseable)) {
				parameter.addError("A resource for try-with-resources must implement AutoCloseable!")
			}
		}
	}

	@FinalFieldsConstructor
	private static class TypeInfo {
		val extension TypeReferenceProvider provider

		/**
		 * Checks whether the provided {@code typeReference} implements or
		 * extends the provided {@code superType}.
		 * 
		 * @param typeReference
		 * 		A type reference.
		 * @param superType
		 * 		The type to look for.
		 * @return {@code true} iff {@code typeReference} or any of its super
		 *  types is {@code superType}.
		 */
		def private hasSuperType(TypeReference typeReference, Class<?> superType) {
			typeReference.withAllSuperTypes.contains(newTypeReference(superType))
		}

		def private Set<? extends TypeReference> withAllSuperTypes(TypeReference typeReference) {
			(#[typeReference] + typeReference.declaredSuperTypes.map[withAllSuperTypes].flatten).toSet
		}
	}

}
