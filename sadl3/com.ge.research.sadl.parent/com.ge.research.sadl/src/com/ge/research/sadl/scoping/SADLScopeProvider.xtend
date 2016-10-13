/*
 * generated by Xtext 2.9.0-SNAPSHOT
 */
/************************************************************************
 * Copyright © 2007-2016 - General Electric Company, All Rights Reserved
 *
 * Project: SADL
 *
 * Description: The Semantic Application Design Language (SADL) is a
 * language for building semantic models and expressing rules that
 * capture additional domain knowledge. The SADL-IDE (integrated
 * development environment) is a set of Eclipse plug-ins that
 * support the editing and testing of semantic models using the
 * SADL language.
 *
 * This software is distributed "AS-IS" without ANY WARRANTIES
 * and licensed under the Eclipse Public License - v 1.0
 * which is available at http://www.eclipse.org/org/documents/epl-v10.php
 *
 ***********************************************************************/
package com.ge.research.sadl.scoping

import com.ge.research.sadl.model.DeclarationExtensions
import com.ge.research.sadl.sADL.BinaryOperation
import com.ge.research.sadl.sADL.EquationStatement
import com.ge.research.sadl.sADL.Expression
import com.ge.research.sadl.sADL.PropOfSubject
import com.ge.research.sadl.sADL.RuleStatement
import com.ge.research.sadl.sADL.SADLPackage
import com.ge.research.sadl.sADL.SadlClassOrPropertyDeclaration
import com.ge.research.sadl.sADL.SadlImport
import com.ge.research.sadl.sADL.SadlModel
import com.ge.research.sadl.sADL.SadlMustBeOneOf
import com.ge.research.sadl.sADL.SadlProperty
import com.ge.research.sadl.sADL.SadlResource
import com.ge.research.sadl.sADL.SubjHasProp
import com.google.common.base.Predicate
import com.google.inject.Inject
import java.util.List
import java.util.Map
import java.util.Set
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.naming.IQualifiedNameConverter
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.resource.EObjectDescription
import org.eclipse.xtext.resource.ForwardingEObjectDescription
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.scoping.IScope
import org.eclipse.xtext.scoping.impl.AbstractGlobalScopeDelegatingScopeProvider
import org.eclipse.xtext.scoping.impl.MapBasedScope
import org.eclipse.xtext.util.OnChangeEvictingCache
import com.ge.research.sadl.sADL.SadlInstance
import com.ge.research.sadl.sADL.QueryStatement
import com.ge.research.sadl.sADL.TestStatement

/**
 * This class contains custom scoping description.
 * 
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#scoping
 * on how and when to use it.
 */
class SADLScopeProvider extends AbstractGlobalScopeDelegatingScopeProvider {

	@Inject extension DeclarationExtensions
	@Inject OnChangeEvictingCache cache
	@Inject IQualifiedNameConverter converter
	
	boolean ambiguousNameDetection;
	
	override getScope(EObject context, EReference reference) {
		val ctxrsrc = context.eResource();
		setAmbiguousNameDetection(TestScopeProvider.getDetectAmbiguousNames(ctxrsrc));
		// resolving imports against external models goes directly to the global scope
		if (reference.EReferenceType === SADLPackage.Literals.SADL_MODEL) {
			return super.getGlobalScope(context.eResource, reference)
		}
		if (SADLPackage.Literals.SADL_RESOURCE.isSuperTypeOf(reference.EReferenceType)) {
			return getSadlResourceScope(context, reference)
		}
		throw new UnsupportedOperationException(
			"Couldn't build scope for elements of type " + reference.EReferenceType.name)
	}
	
	def setAmbiguousNameDetection(boolean bval) {
		ambiguousNameDetection = bval
	}

	protected def IScope getSadlResourceScope(EObject context, EReference reference) {
		val parent = createResourceScope(context.eResource, null, newHashSet)
		
		val rule = EcoreUtil2.getContainerOfType(context, RuleStatement)
		if (rule !== null) {
			return getLocalVariableScope(rule.ifs + rule.thens, parent)
		}
		val equation = EcoreUtil2.getContainerOfType(context, EquationStatement)
		if (equation !== null) {
			return MapBasedScope.createScope(parent, 
				equation.parameter.map[EObjectDescription.create(name.concreteName, it.name)])
		}
		val ask = EcoreUtil2.getContainerOfType(context, QueryStatement)
		if (ask !== null) {
			return getLocalVariableScope(ask.expr, parent)
		}
		val test = EcoreUtil2.getContainerOfType(context, TestStatement)
		if (test !== null) {
			return getLocalVariableScope(test.tests, parent)
		}
		return parent
	}
	
	protected def IScope getLocalVariableScope(Iterable<Expression> expressions, IScope parent) {
		if (expressions.empty)
			return parent;
		var newParent = doGetLocalVariableScope(expressions, parent) [
			var container = eContainer
			if (container instanceof PropOfSubject || container instanceof SubjHasProp) {
				container = container.eContainer
			}
			if (container instanceof BinaryOperation) {
				if (container.op == 'is' || container.op == '==' || container.op == '=') 
					return true
			}
			return false
		]
		return doGetLocalVariableScope(expressions, newParent) [true]
	}
	
	protected def IScope getLocalVariableScope(Expression expression, IScope parent) {
		var newParent = doGetLocalVariableScope(expression, parent) [
			var container = eContainer
			if (container instanceof PropOfSubject || container instanceof SubjHasProp) {
				container = container.eContainer
			}
			if (container instanceof BinaryOperation) {
				if (container.op == 'is' || container.op == '==' || container.op == '=') 
					return true
			}
			return false
		]
		return doGetLocalVariableScope(expression, newParent) [true]
	}
	
	protected def IScope doGetLocalVariableScope(Iterable<Expression> expressions, IScope parent, Predicate<SadlResource> predicate) {
		 if (expressions.empty)
			return parent;
		val map = newHashMap
		for (expression : expressions) {
			val iter = EcoreUtil2.getAllContents(expression, false).filter(SadlResource).filter(predicate)
			while (iter.hasNext) {
				val name = iter.next
				val concreteName = name.concreteName
				if (concreteName !== null) {
					val qn = QualifiedName.create(concreteName)
					if (!map.containsKey(qn) && parent.getSingleElement(qn) === null) {
						map.put(qn, new EObjectDescription(qn, name, emptyMap))
					}
				}
			}
		}
		return MapBasedScope.createScope(parent, map.values)
	}
	
	
	protected def IScope doGetLocalVariableScope(Expression expression, IScope parent, Predicate<SadlResource> predicate) {
		val map = newHashMap
		val iter = EcoreUtil2.getAllContents(expression, false).filter(SadlResource).filter(predicate)
		while (iter.hasNext) {
			val name = iter.next
			val concreteName = name.concreteName
			if (concreteName !== null) {
				val qn = QualifiedName.create(concreteName)
				if (!map.containsKey(qn) && parent.getSingleElement(qn) === null) {
					map.put(qn, new EObjectDescription(qn, name, emptyMap))
				}
			}
		}
		return MapBasedScope.createScope(parent, map.values)
	}
	
	protected def IScope createResourceScope(Resource resource, String alias, Set<Resource> importedResources) {
		return cache.get('resource_scope'->alias, resource) [
			val shouldWrap = importedResources.empty
			if (!importedResources.add(resource)) {
				return IScope.NULLSCOPE
			}
			
			var newParent = createImportScope(resource, importedResources)
			if (shouldWrap)
				newParent = wrap(newParent)
			val aliasToUse = alias ?: resource.getAlias
			val namespace = if (aliasToUse!==null) QualifiedName.create(aliasToUse) else null
			newParent = getLocalScope1(resource, namespace, newParent)
			newParent = getLocalScope2(resource, namespace, newParent)
			newParent = getLocalScope3(resource, namespace, newParent)
			newParent = getLocalScope4(resource, namespace, newParent)
			// finally all the rest
			newParent = internalGetLocalResourceScope(resource, namespace, newParent) [true]
			return newParent
		]
	}
	
	protected def getLocalScope4(Resource resource, QualifiedName namespace, IScope parentScope) {
		return internalGetLocalResourceScope(resource, namespace, parentScope) [
			if (it instanceof SadlResource) {
				return eContainer instanceof SadlMustBeOneOf && eContainingFeature == SADLPackage.Literals.SADL_MUST_BE_ONE_OF__VALUES
			} 
			return false
		]
	}
	
	protected def getLocalScope3(Resource resource, QualifiedName namespace, IScope parentScope) {
		return internalGetLocalResourceScope(resource, namespace, parentScope) [
			if (it instanceof SadlResource) {
				return eContainer instanceof SadlInstance && eContainingFeature == SADLPackage.Literals.SADL_INSTANCE__NAME_OR_REF
			} 
			return false
		]
	}
	
	protected def getLocalScope2(Resource resource, QualifiedName namespace, IScope parentScope) {
		return internalGetLocalResourceScope(resource, namespace, parentScope) [
			if (it instanceof SadlResource) {
				return eContainer instanceof SadlProperty && eContainingFeature == SADLPackage.Literals.SADL_PROPERTY__NAME_OR_REF
					|| eContainer instanceof SadlProperty && eContainingFeature == SADLPackage.Literals.SADL_PROPERTY__NAME_DECLARATIONS
			} 
			return false
		]
	}
	
	protected def getLocalScope1(Resource resource, QualifiedName namespace, IScope parentScope) {
		return internalGetLocalResourceScope(resource, namespace, parentScope) [
			if (it instanceof SadlResource) {
				return eContainer instanceof SadlClassOrPropertyDeclaration && eContainingFeature == SADLPackage.Literals.SADL_CLASS_OR_PROPERTY_DECLARATION__CLASS_OR_PROPERTY
					|| eContainer instanceof SadlProperty && (eContainer as SadlProperty).isPrimaryDeclaration() && eContainingFeature == SADLPackage.Literals.SADL_PROPERTY__NAME_OR_REF
					
			} 
			return false
		]
	}
	
	def IScope internalGetLocalResourceScope(Resource resource, QualifiedName namespace, IScope parentScope, Predicate<EObject> isIncluded) {
		val map = <QualifiedName, IEObjectDescription>newHashMap
		val iter = resource.allContents
		while (iter.hasNext) {
			val it = iter.next
			if (isIncluded.apply(it)) {
				switch it {
					SadlResource case concreteName !== null: {
						val name1 = converter.toQualifiedName(concreteName)
						if (parentScope.getSingleElement(name1) === null) {
							map.addElement(name1, it)
						}
						val name2 = if (name1.segments.size==1) namespace?.append(name1) else name1.skipFirst(1)
						if (name2 !== null && parentScope.getSingleElement(name2) === null) {
							map.addElement(name2, it)
						}
					}
					EquationStatement : {
						val name = converter.toQualifiedName(it.name.concreteName)
						map.addElement(name, it.name)
						if (name.segmentCount > 1) {
							map.addElement(name.skipFirst(1), it.name)
						} else if (namespace !== null) {
							map.addElement(namespace.append(name), it.name)
						}
					}
					default :
						if (pruneScope(it)) {
							iter.prune
						}
				}
			}
		}
		return MapBasedScope.createScope(parentScope, map.values)
	}
	
	protected def pruneScope(EObject object) {
		return object instanceof RuleStatement || object instanceof EquationStatement || object instanceof QueryStatement || object instanceof TestStatement
	}
	
	protected def String getAlias(Resource resource) {
		(resource.contents.head as SadlModel).alias
	}
	
	protected def IScope createImportScope(Resource resource, Set<Resource> importedResources) {
		val imports = resource.contents.head.eContents.filter(SadlImport).toList.reverseView
		var importScopes = newArrayList
		for (imp : imports) {
			val externalResource = imp.importedResource
			if (!externalResource.eIsProxy)
				importScopes += createResourceScope(externalResource.eResource, imp.alias, importedResources)
		}
		if (importScopes.isEmpty) {
			if (!resource.URI.toString.endsWith("SadlImplicitModel.sadl")) {
				val element = getGlobalScope(resource, SADLPackage.Literals.SADL_IMPORT__IMPORTED_RESOURCE).getSingleElement(QualifiedName.create("http://sadl.org/sadlimplicitmodel"))
				if (element !== null) {
					val eobject = resource.resourceSet.getEObject(element.EObjectURI, true)
					if (eobject !== null) {
						importScopes += createResourceScope(eobject.eResource, null, importedResources)
					}
				}
			}
		}
		return new ListCompositeScope(importScopes, converter, ambiguousNameDetection)
	}

	private def void addElement(Map<QualifiedName, IEObjectDescription> scope, QualifiedName qn, EObject obj) {
		if (!scope.containsKey(qn)) {
			scope.put(qn, new EObjectDescription(qn, obj, emptyMap))
		}
	}

	@Data static class ListCompositeScope implements IScope {
	
		List<IScope> delegates
		IQualifiedNameConverter converter
		boolean detectAmbiguousNames;
		
		override getAllElements() {
			delegates.map[allElements].reduce[p1, p2| p1 + p2]
		}
		
		override getElements(QualifiedName name) {
			val registered = newHashSet
			return delegates.map[getElements(name)].flatten.filter[registered.add(it.EObjectURI)]
		}
		
		override getElements(EObject object) {
			return delegates.map[getElements(object)].flatten
		}
		
		override getSingleElement(QualifiedName name) {
			if (!detectAmbiguousNames) {
				for (s : delegates) {
					val element = s.getSingleElement(name);
					if (element !== null) {
						return element
					}
				}
				return null;
			}
			var List<IEObjectDescription> candidates = null
			var IEObjectDescription firstMatch = null
			for (s : delegates) {
				val candidate = s.getSingleElement(name)
				if (candidate !== null && firstMatch !== candidate) {
					if (firstMatch === null) {
						firstMatch = candidate 
					} else {
						if (candidates === null) {
							candidates = newArrayList
							candidates.add(firstMatch)
						}
						if (!candidates.contains(candidate))
							candidates.add(candidate)
					}
				}
			}
			if (candidates === null) {
				return firstMatch
			} else {
				val imports = candidates.map[EObjectOrProxy.eResource.allContents.filter(SadlModel).head.baseUri]
				val message = '''Ambiguously imported name '«name»' from «imports.map["'"+it+"'"].join(", ")». Please use an alias or choose different names.'''
				val alternatives = candidates.map[
					desc | 
					this.getElements(desc.EObjectOrProxy)
						.filter
						[
							qualifiedName != desc.qualifiedName
						]
				].flatten.toList
				
				return new ForwardingEObjectDescription(candidates.head) {
					override getUserData(String key) {
						if (key.equals(ErrorAddingLinkingService.ERROR)) {
							return message
						}
						if (key.equals(ErrorAddingLinkingService.ALTERNATIVES)) {
							return alternatives.join(",", [converter.toString(name)])
						}
						super.getUserData(key)
					}
				}
			}
		}
		
		override getSingleElement(EObject object) {
			for (scope : delegates) {
				val element = scope.getSingleElement(object)
				if (element !== null) {
					return element
				}
			}
			return null
		}
		
	}
	
}
