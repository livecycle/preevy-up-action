import {exec} from 'child_process';
import * as core from '@actions/core';

async function run(): Promise<void> {
  try {
    const baseUrl: string = core.getInput('baseUrl', {required: true});
    const files: string[] = core
      .getInput('files')
      .split(' ')
      .filter((x) => x.endsWith('.mdx'));

    core.setOutput('annotations', []);
    core.setFailed(`failed`);
  } catch (error) {
    core.setFailed(`failed`);
  }
}

run();
