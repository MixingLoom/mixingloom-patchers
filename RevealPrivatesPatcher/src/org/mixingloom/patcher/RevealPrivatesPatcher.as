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
import org.as3commons.bytecode.abc.MethodInfo;
import org.as3commons.bytecode.abc.TraitInfo;
import org.as3commons.bytecode.io.AbcDeserializer;
import org.as3commons.bytecode.io.AbcSerializer;
import org.as3commons.bytecode.io.MethodBodyExtractionKind;
import org.mixingloom.SwfContext;
import org.mixingloom.SwfTag;
import org.mixingloom.invocation.InvocationType;
import org.mixingloom.utils.HexDump;

public class RevealPrivatesPatcher extends AbstractPatcher {

  public var className:String;

  public var tagName:String;

  public var propertyOrMethodName:String;

  public function RevealPrivatesPatcher(tagName:String, className:String, propertyOrMethodName:String)
  {
    this.tagName = tagName;
    this.className = className;
    this.propertyOrMethodName = propertyOrMethodName;
  }

  override public function apply( invocationType:InvocationType, swfContext:SwfContext ):void {

    for each (var swfTag:SwfTag in swfContext.swfTags)
    {
      if (((swfTag.name == tagName) || (tagName == null)) && (swfTag.type == 82))
      {
        var needsModification:Boolean = false;

        // skip the flags
        swfTag.tagBody.position = 4;

        var abcStartLocation:uint = 4;
        while (swfTag.tagBody.readByte() != 0)
        {
          abcStartLocation++;
        }
        abcStartLocation++; // skip the string byte terminator

        //trace("abcStartLocation = " + abcStartLocation);

        //trace(swfTag.name);
        //trace(swfTag.type);
        //trace(HexDump.dumpHex(swfTag.tagBody));

        swfTag.tagBody.position = 0;

        var abcDeserializer:AbcDeserializer = new AbcDeserializer(swfTag.tagBody);
        //abcDeserializer.methodBodyExtractionMethod = MethodBodyExtractionKind.BYTEARRAY;

        var origAbcFile:AbcFile = abcDeserializer.deserialize(abcStartLocation);

        for each (var ii:InstanceInfo in origAbcFile.instanceInfo)
        {
          if (ii.classMultiname.fullName == className)
          {
            //trace('FOUND ' + className);

            for each (var t:TraitInfo in ii.traits)
            {
              if (t.traitMultiname.name == propertyOrMethodName)
              {
                //trace('trait ' + propertyOrMethodName);
                t.traitMultiname.nameSpace = LNamespace.PUBLIC;

                needsModification = true;
              }
            }

            //trace('modified ' + propertyOrMethodName);
          }
        }

        // if we didn't modify anything, then just continue
        if (!needsModification)
        {
          continue;
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
        if (swfTag.name != null)
        {
          swfTag.tagBody.writeUTFBytes(swfTag.name);
        }
        swfTag.tagBody.writeByte(0);

        // method body
        swfTag.tagBody.writeBytes(abcByteArray);

        swfTag.recordHeader = new ByteArray();
        swfTag.recordHeader.endian = Endian.LITTLE_ENDIAN;
        swfTag.recordHeader.writeByte(0xbf);
        swfTag.recordHeader.writeByte(0x14);
        swfTag.recordHeader.writeInt(swfTag.tagBody.length);

        swfTag.modified = true;

        //trace(HexDump.dumpHex(swfTag.tagBody));
      }
    }

    invokeCallBack();
  }

}
}