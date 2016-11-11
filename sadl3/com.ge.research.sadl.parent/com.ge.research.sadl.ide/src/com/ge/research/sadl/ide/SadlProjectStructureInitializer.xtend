/************************************************************************
 * Copyright 2007-2016- General Electric Company, All Rights Reserved
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
package com.ge.research.sadl.ide

import com.google.inject.Singleton
import java.io.FileWriter
import java.nio.file.Files
import java.nio.file.Path
import org.eclipse.emf.common.util.URI

import static com.ge.research.sadl.processing.SadlConstants.*
import static com.ge.research.sadl.jena.UtilsForJena.*

import static extension com.google.common.base.Preconditions.*

/**
 * Singleton class for initializing the SADL project structure.
 * 
 * @author akos.kitta
 */
@Singleton
class SadlProjectStructureInitializer {
	
	static val OWL_BASE_MODEL_FILENAME = '''«SADL_BASE_MODEL_FILENAME».owl''';
	
	static val IMPLICIT_MODEL_CONTENT = '''
	uri "http://sadl.org/sadlimplicitmodel" alias sadlimplicitmodel.
	Event is a class.
	impliedProperty is a type of annotation.
	UnittedQuantity is a class,
	 	described by ^value with values of type decimal,
	 	described by unit with values of type string.
	''';

	static val IMPLICIT_OWL_MODEL_CONTENT = '''
	<rdf:RDF
	    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	    xmlns:owl="http://www.w3.org/2002/07/owl#"
	    xmlns:sadlimplicitmodel="http://sadl.org/sadlimplicitmodel#"
	    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
	    xmlns:xsd="http://www.w3.org/2001/XMLSchema#"
	  xml:base="http://sadl.org/sadlimplicitmodel">
	  <owl:Ontology rdf:about="">
	    <rdfs:comment xml:lang="en">This ontology was created from a SADL file 'SadlImplicitModel.sadl' and should not be directly edited.</rdfs:comment>
	  </owl:Ontology>
	  <owl:Class rdf:ID="UnittedQuantity"/>
	  <owl:Class rdf:ID="Event"/>
	  <owl:DatatypeProperty rdf:ID="value">
	    <rdfs:domain rdf:resource="#UnittedQuantity"/>
	    <rdfs:range rdf:resource="http://www.w3.org/2001/XMLSchema#decimal"/>
	  </owl:DatatypeProperty>
	  <owl:DatatypeProperty rdf:ID="unit">
	    <rdfs:domain rdf:resource="#UnittedQuantity"/>
	    <rdfs:range rdf:resource="http://www.w3.org/2001/XMLSchema#string"/>
	  </owl:DatatypeProperty>
	  <owl:AnnotationProperty rdf:ID="impliedProperty"/>
	</rdf:RDF>
	''';
	
	static val BASE_OWL_MODEL_CONTENT = '''
	<rdf:RDF
	    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	    xmlns:owl="http://www.w3.org/2002/07/owl#"
	    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
	    xmlns:sadlbasemodel="http://sadl.org/sadlbasemodel#"
	    xmlns:xsd="http://www.w3.org/2001/XMLSchema#">
	  <owl:Ontology rdf:about="">
	    <rdfs:comment xml:lang="en">Base model for SADL. These concepts can be used without importing.</rdfs:comment>
	  </owl:Ontology>
	  <owl:Class rdf:ID="ExternalEquation"/>
	  <owl:Class rdf:ID="Equation"/>
	  <owl:DatatypeProperty rdf:ID="externalURI">
	    <rdfs:range rdf:resource="http://www.w3.org/2001/XMLSchema#anyURI"/>
	    <rdfs:domain rdf:resource="#Equation"/>
	  </owl:DatatypeProperty>
	  <owl:DatatypeProperty rdf:ID="expression">
	    <rdfs:range rdf:resource="http://www.w3.org/2001/XMLSchema#string"/>
	    <rdfs:domain rdf:resource="#Equation"/>
	  </owl:DatatypeProperty>
	</rdf:RDF>	
	''';
	
	private static def String getOntologyPolicyRdfContent(Path rootPath)'''
	<rdf:RDF
	    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	    xmlns:j.0="http://jena.hpl.hp.com/schemas/2003/03/ont-manager#">
	  <j.0:OntologySpec>
	    <j.0:publicURI rdf:resource="http://sadl.org/sadlimplicitmodel"/>
	    <j.0:altURL rdf:resource="«URI.createFileURI(rootPath.toString)»/«OWL_MODELS_FOLDER_NAME»/«OWL_IMPLICIT_MODEL_FILENAME»"/>
	    <j.0:language rdf:resource="http://www.w3.org/2002/07/owl"/>
	    <j.0:createdBy>SADL</j.0:createdBy>
	    <j.0:prefix rdf:datatype="http://www.w3.org/2001/XMLSchema#string"
	    >sadlimplicitmodel</j.0:prefix>
	  </j.0:OntologySpec>
	  <j.0:OntologySpec>
	    <j.0:publicURI rdf:resource="http://sadl.org/sadlbasemodel"/>
	    <j.0:altURL rdf:resource="«URI.createFileURI(rootPath.toString)»/«OWL_MODELS_FOLDER_NAME»/«OWL_BASE_MODEL_FILENAME»"/>
	    <j.0:language rdf:resource="http://www.w3.org/2002/07/owl"/>
	    <j.0:createdBy>SADL</j.0:createdBy>
	    <j.0:prefix rdf:datatype="http://www.w3.org/2001/XMLSchema#string"
	    >sadlbasemodel</j.0:prefix>
	  </j.0:OntologySpec>
	</rdf:RDF>
	'''
	
	/**
	 * Initializes the SADL project structure on demand.
	 * 
	 * @param projectRoot the path to the project root.
	 */
	def void initialize(Path projectRoot) {
		val implicitModelRoot = projectRoot.resolve(SADL_IMPLICIT_MODEL_FOLDER);
		if (!implicitModelRoot.toFile.exists) {
			Files.createDirectory(implicitModelRoot);
		}
		implicitModelRoot.createImplicitModelFileIfMissing;
		
		val owlModelsRoot = projectRoot.resolve(OWL_MODELS_FOLDER_NAME);
		if (!owlModelsRoot.toFile.exists) {
			Files.createDirectories(owlModelsRoot);
		}
		owlModelsRoot.createBaseOwlFileIfMissing;
		owlModelsRoot.createImplicitModelOwlFileIfMissing;
		owlModelsRoot.createOntologyPolicyRdfFileIfMissing;
	}
	
	private def void createOntologyPolicyRdfFileIfMissing(Path owlModelsRoot) {
		owlModelsRoot.createFileIfMissing(ONT_POLICY_FILENAME, getOntologyPolicyRdfContent(owlModelsRoot));
	}

	private def createImplicitModelOwlFileIfMissing(Path owlModelsRoot) {
		owlModelsRoot.createFileIfMissing(OWL_IMPLICIT_MODEL_FILENAME, IMPLICIT_OWL_MODEL_CONTENT);		
	}
	
	private def createBaseOwlFileIfMissing(Path owlModelsRoot) {
		owlModelsRoot.createFileIfMissing(OWL_BASE_MODEL_FILENAME, BASE_OWL_MODEL_CONTENT);		
	}
	
	private def createImplicitModelFileIfMissing(Path implicitModelRoot) {
		implicitModelRoot.createFileIfMissing(SADL_IMPLICIT_MODEL_FILENAME, IMPLICIT_MODEL_CONTENT);
	}
	
	private def createFileIfMissing(Path rootFolder, String fileName, String content) {
		rootFolder.toFile.directory.checkArgument('''Cannot find root directory for file «fileName» under: «rootFolder».''');
		val filePath = rootFolder.resolve(fileName);
		val file = filePath.toFile;
		if (!file.exists) {
			Files.createFile(filePath);
			val writer = new FileWriter(file);
			writer.write(content);
			writer.flush();
			writer.close();
		}
	}
	
}