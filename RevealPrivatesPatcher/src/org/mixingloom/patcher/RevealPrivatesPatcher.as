/**
 * Created by IntelliJ IDEA.
 * User: James Ward <james@jamesward.org>
 * Date: 3/23/11
 * Time: 1:34 PM
 */
package org.mixingloom.patcher
{
import flash.utils.ByteArray;
import flash.utils.Endian;

import org.as3commons.bytecode.abc.AbcFile;
import org.as3commons.bytecode.abc.InstanceInfo;
import org.as3commons.bytecode.abc.LNamespace;
import org.as3commons.bytecode.abc.MethodBody;
import org.as3commons.bytecode.abc.TraitInfo;
import org.as3commons.bytecode.io.AbcDeserializer;
import org.as3commons.bytecode.io.AbcSerializer;
import org.mixingloom.SwfContext;
import org.mixingloom.SwfTag;
import org.mixingloom.invocation.InvocationType;

public class RevealPrivatesPatcher extends AbstractPatcher {

  public var classTagName:String;

  public var propertyOrMethodName:String;

  public function RevealPrivatesPatcher(classTagName:String, propertyOrMethodName:String)
  {
    this.classTagName = classTagName;
    this.propertyOrMethodName = propertyOrMethodName;
  }

  override public function apply( invocationType:InvocationType, swfContext:SwfContext ):void {
    applier.startPatching( this );

    if ( invocationType.type != InvocationType.FRAME2 ) {
      applier.completePatching( this );

      return;
    }

    run(swfContext.swfTags);

    applier.completePatching( this );
  }

  public function run(swfTags:Vector.<SwfTag>):void
  {
    for each (var swfTag:SwfTag in swfTags)
    {
      if (swfTag.name == classTagName)
      {
        // skip the flags
        swfTag.tagBody.position = 4;

        var abcStartLocation:uint = 4;
        while (swfTag.tagBody.readByte() != 0)
        {
          abcStartLocation++;
        }
        abcStartLocation++; // skip the string byte terminator

        swfTag.tagBody.position = 0;

        var abcDeserializer:AbcDeserializer = new AbcDeserializer(swfTag.tagBody);

        var origAbcFile:AbcFile = abcDeserializer.deserialize(abcStartLocation);

        // check the methods
        for each (var mb:MethodBody in origAbcFile.methodBodies)
        {
          if (!(mb.methodSignature.as3commonsBytecodeName is String))
          {
            if (mb.methodSignature.as3commonsBytecodeName.name == propertyOrMethodName)
            {
              mb.methodSignature.as3commonsBytecodeName.nameSpace = LNamespace.PUBLIC;
              mb.methodSignature.scopeName = mb.methodSignature.as3commonsBytecodeName.nameSpace.kind.description;
            }
          }
        }

        for each (var ci:InstanceInfo in origAbcFile.instanceInfo)
        {
          for each (var t:TraitInfo in ci.traits)
          {
            if (t.traitMultiname.name == propertyOrMethodName)
            {
              t.traitMultiname.nameSpace = LNamespace.PUBLIC;
            }
          }
        }

        var abcSerializer:AbcSerializer = new AbcSerializer();
        var abcByteArray:ByteArray = abcSerializer.serializeAbcFile(origAbcFile);

        swfTag.tagBody = new ByteArray();
        swfTag.tagBody.endian = Endian.LITTLE_ENDIAN;

        // 4 byte flags
        swfTag.tagBody.writeByte(0x01);
        swfTag.tagBody.writeByte(0);
        swfTag.tagBody.writeByte(0);
        swfTag.tagBody.writeByte(0);

        // tag name
        swfTag.tagBody.writeUTFBytes(classTagName);
        swfTag.tagBody.writeByte(0);

        // method body
        swfTag.tagBody.writeBytes(abcByteArray);

        swfTag.recordHeader = new ByteArray();
        swfTag.recordHeader.endian = Endian.LITTLE_ENDIAN;
        swfTag.recordHeader.writeByte(0xbf);
        swfTag.recordHeader.writeByte(0x14);
        swfTag.recordHeader.writeInt(swfTag.tagBody.length);

        swfTag.modified = true;
      }
    }
  }

}
}