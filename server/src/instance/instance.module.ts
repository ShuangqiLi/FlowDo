import { Global, Module } from '@nestjs/common';
import { InstanceService } from './instance.service';

@Global()
@Module({
  providers: [InstanceService],
  exports: [InstanceService],
})
export class InstanceModule {}
